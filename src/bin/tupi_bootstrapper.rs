use std::env;
use std::error::Error;
use std::fs;
use std::fs::File;
use std::io::{Cursor, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::fs::symlink;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

const APPENDED_MARKER: &[u8] = b"TUPI_ZIP_APPENDED";
const MARKER_TOTAL: usize = APPENDED_MARKER.len() + 8;

const MAIN_ENTRY: &str = "__main__";
const ENGINE_ENTRY: &str = "__engine__";
const SCRIPTS_PREFIX: &str = "scripts/";
const LIB_PREFIX: &str = "lib/";
const ASSETS_PREFIX: &str = "assets/";

const ENGINE_SUBDIR: &str = "engine";
const ENGINE_BIN_NAME: &str = "tupi_engine";
const SCRIPTS_SIDECAR_NAME: &str = "game.tuzip";

fn main() {
    if let Err(err) = run() {
        eprintln!("[Bootstrap] {}", err);
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let exe_path = env::current_exe()?;
    let exe_bytes = fs::read(&exe_path)?;
    let zip_offset = read_appended_zip_offset(&exe_bytes)
        .ok_or("nenhum ZIP anexado encontrado neste executavel")?;

    if zip_offset >= exe_bytes.len() {
        return Err("offset do ZIP anexado invalido".into());
    }

    let zip_end = exe_bytes
        .len()
        .checked_sub(MARKER_TOTAL)
        .ok_or("executavel menor que o trailer do bundle")?;
    if zip_offset >= zip_end {
        return Err("ZIP anexado vazio ou truncado".into());
    }

    let tmpdir = create_tmpdir()?;
    let engine_path = tmpdir.join(ENGINE_SUBDIR).join(ENGINE_BIN_NAME);
    let lib_dir = tmpdir.join("lib");
    let assets_dir = tmpdir.join("assets");
    let scripts_path = tmpdir.join(SCRIPTS_SIDECAR_NAME);

    let zip_slice = &exe_bytes[zip_offset..zip_end];
    let cursor = Cursor::new(zip_slice);
    let mut archive = ZipArchive::new(cursor)?;

    let mut found_engine = false;
    let mut found_libs = false;
    let mut found_assets = false;
    let mut scripts: Vec<(String, Vec<u8>)> = Vec::new();

    for index in 0..archive.len() {
        let mut entry = archive.by_index(index)?;
        let name = entry.name().replace('\\', "/");
        if entry.is_dir() {
            continue;
        }

        let mut data = Vec::new();
        entry.read_to_end(&mut data)?;

        if name == ENGINE_ENTRY {
            write_file(&engine_path, &data, 0o755)?;
            found_engine = true;
            eprintln!(
                "[Bootstrap] Engine extraido: {} ({} bytes)",
                engine_path.display(),
                data.len()
            );
            continue;
        }

        if let Some(rel_name) = name.strip_prefix(LIB_PREFIX) {
            let dest = lib_dir.join(rel_name);
            write_file(&dest, &data, 0o644)?;
            found_libs = true;
            eprintln!("[Bootstrap] Lib extraida: {} ({} bytes)", rel_name, data.len());
            continue;
        }

        if let Some(rel_name) = name.strip_prefix(ASSETS_PREFIX) {
            let clean_rel = rel_name.trim_start_matches('/');
            let dest = assets_dir.join(clean_rel);
            write_file(&dest, &data, 0o644)?;
            found_assets = true;
            continue;
        }

        if name == MAIN_ENTRY || name.starts_with(SCRIPTS_PREFIX) {
            scripts.push((name, data));
        }
    }

    if !found_engine {
        return Err("entrada '__engine__' nao encontrada no bundle".into());
    }

    write_scripts_zip(&scripts_path, &scripts)?;
    eprintln!("[Bootstrap] Scripts em: {}", scripts_path.display());

    if found_libs {
        create_soname_symlinks(&lib_dir)?;
        prepend_env_path("LD_LIBRARY_PATH", &lib_dir);
    }

    env::set_var("TUPI_SCRIPT_ARCHIVE", &scripts_path);

    if found_assets {
        env::set_var("TUPI_ASSET_DIR", &assets_dir);
        eprintln!("[Bootstrap] Assets em: {}", assets_dir.display());
    }

    let argv: Vec<_> = env::args_os().skip(1).collect();
    eprintln!("[Bootstrap] Iniciando engine: {}", engine_path.display());

    let err = Command::new(&engine_path).args(argv).exec();
    Err(format!(
        "falha ao executar engine '{}': {}",
        engine_path.display(),
        err
    )
    .into())
}

fn read_appended_zip_offset(exe_bytes: &[u8]) -> Option<usize> {
    if exe_bytes.len() < MARKER_TOTAL {
        return None;
    }

    let tail = &exe_bytes[exe_bytes.len() - MARKER_TOTAL..];
    if &tail[..APPENDED_MARKER.len()] != APPENDED_MARKER {
        return None;
    }

    let mut raw = [0u8; 8];
    raw.copy_from_slice(&tail[APPENDED_MARKER.len()..]);
    usize::try_from(u64::from_le_bytes(raw)).ok()
}

fn create_tmpdir() -> Result<PathBuf, Box<dyn Error>> {
    let base = env::temp_dir();
    let pid = std::process::id();
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos();

    for attempt in 0..64u32 {
        let candidate = base.join(format!("tupi_{}_{}_{}", pid, stamp, attempt));
        match fs::create_dir(&candidate) {
            Ok(()) => return Ok(candidate),
            Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(err) => return Err(err.into()),
        }
    }

    Err("nao foi possivel criar diretorio temporario do bundle".into())
}

fn write_file(path: &Path, data: &[u8], mode: u32) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let mut file = File::create(path)?;
    file.write_all(data)?;
    file.sync_all()?;

    let mut perms = file.metadata()?.permissions();
    perms.set_mode(mode);
    fs::set_permissions(path, perms)?;
    Ok(())
}

fn write_scripts_zip(
    dest_path: &Path,
    scripts: &[(String, Vec<u8>)],
) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let file = File::create(dest_path)?;
    let mut zip = ZipWriter::new(file);
    let opts = SimpleFileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .compression_level(Some(6));

    for (name, data) in scripts {
        zip.start_file(name, opts)?;
        zip.write_all(data)?;
    }

    zip.finish()?;
    Ok(())
}

/// Para cada lib com nome real versionado (ex: libzip.so.4.0),
/// cria um symlink soname (ex: libzip.so.4 -> libzip.so.4.0)
/// caso ainda nao exista. Isso permite que o dynamic linker
/// resolva dependencias que referenciam apenas o soname.
fn create_soname_symlinks(lib_dir: &Path) -> Result<(), Box<dyn Error>> {
    for entry in fs::read_dir(lib_dir)? {
        let entry = entry?;
        let file_name = entry.file_name();
        let name = file_name.to_string_lossy();

        // Procura pelo padrao ".so." no nome do arquivo
        // Ex: "libzip.so.4.0", "libSDL2-2.0.so.0.3000.0"
        let so_pos = match name.find(".so.") {
            Some(p) => p,
            None => continue,
        };

        // Extrai apenas o numero major apos ".so."
        // Ex: "4.0" -> major = "4"
        let after_so = &name[so_pos + 4..];
        let major = match after_so.split('.').next() {
            Some(m) if !m.is_empty() => m,
            _ => continue,
        };

        // Se o nome ja e o soname (sem versao alem do major), nao precisa de symlink
        if after_so == major {
            continue;
        }

        // Monta o soname: "libzip.so.4"
        let soname = format!("{}.so.{}", &name[..so_pos], major);
        let symlink_path = lib_dir.join(&soname);

        if !symlink_path.exists() {
            symlink(entry.path().file_name().unwrap(), &symlink_path)?;
            eprintln!("[Bootstrap] Symlink soname: {} -> {}", soname, name);
        }
    }

    Ok(())
}

fn prepend_env_path(name: &str, value: &Path) {
    let new_value = match env::var_os(name) {
        Some(old) if !old.is_empty() => {
            let mut rendered = PathBuf::from(value).into_os_string();
            rendered.push(":");
            rendered.push(old);
            rendered
        }
        _ => value.as_os_str().to_os_string(),
    };

    env::set_var(name, new_value);
}