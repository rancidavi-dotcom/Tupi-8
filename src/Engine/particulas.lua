-- ============================================================
--  particulas.lua  —  Sistema de Partículas estilo PICO-8
--  TupiEngine  |  requer: sintaxe.lua (Tupi) ou engineffi.lua
-- ============================================================
--
--  USO RÁPIDO:
--
--    local P = require("particulas")
--
--    -- Cria um emissor
--    fogo = P.novo({
--        x=100, y=100,
--        quantidade  = 8,          -- partículas por emissão
--        vel_min     = 20,
--        vel_max     = 60,
--        angulo_min  = -math.pi/3, -- leque de direção (radianos)
--        angulo_max  = -math.pi,
--        vida_min    = 0.4,
--        vida_max    = 1.0,
--        tamanho_ini = 4,
--        tamanho_fim = 1,
--        cor_ini     = {1.0, 0.7, 0.0, 1.0},  -- laranja
--        cor_fim     = {1.0, 0.0, 0.0, 0.0},  -- vermelho transparente
--        gravidade   = 30,
--        continuo    = true,       -- emite todo frame
--        intervalo   = 0.05,       -- segundos entre emissões contínuas
--        formato     = "circulo",  -- "circulo" | "quadrado" | "pixel"
--    })
--
--    -- No loop:
--    function _rodar()
--        P.atualizar(fogo, dt)
--    end
--    function _desenhar()
--        P.desenhar(fogo)
--    end
--
--    -- Emissão pontual (explosão, impacto):
--    P.emitir(fogo)
--
--    -- Mover o emissor:
--    P.mover(fogo, nx, ny)
--
--    -- Limpar todas as partículas:
--    P.limpar(fogo)
--
-- ============================================================

local P = {}

-- ── Helpers ──────────────────────────────────────────────────

local rnd   = math.random
local lerp  = function(a, b, t) return a + (b - a) * t end
local floor = math.floor
local cos   = math.cos
local sin   = math.sin

local function rndF(a, b) return a + rnd() * (b - a) end

-- Interpola entre duas cores {r,g,b,a}
local function lerpCor(c1, c2, t)
    return {
        lerp(c1[1], c2[1], t),
        lerp(c1[2], c2[2], t),
        lerp(c1[3], c2[3], t),
        lerp(c1[4] or 1, c2[4] or 1, t),
    }
end

-- ── Defaults ─────────────────────────────────────────────────

local DEFAULTS = {
    x            = 0,
    y            = 0,
    quantidade   = 5,
    vel_min      = 30,
    vel_max      = 80,
    angulo_min   = 0,
    angulo_max   = math.pi * 2,
    vida_min     = 0.5,
    vida_max     = 1.2,
    tamanho_ini  = 4,
    tamanho_fim  = 0,
    cor_ini      = {1.0, 1.0, 1.0, 1.0},
    cor_fim      = {1.0, 1.0, 1.0, 0.0},
    gravidade    = 0,
    atrito       = 0,         -- redução de velocidade por segundo (0-1)
    continuo     = false,
    intervalo    = 0.1,
    formato      = "circulo", -- "circulo" | "quadrado" | "pixel"
    max          = 300,       -- limite de partículas simultâneas
    z_index      = 5,
    espalhamento = 0,         -- raio de origem aleatória ao emitir
}

-- ── Construtor ───────────────────────────────────────────────

--- Cria um novo emissor de partículas.
--- @param cfg table  Configurações (todos opcionais; veja DEFAULTS acima)
--- @return table     Emissor
function P.novo(cfg)
    cfg = cfg or {}
    local e = {}
    for k, v in pairs(DEFAULTS) do
        e[k] = cfg[k] ~= nil and cfg[k] or v
    end
    e._particulas  = {}
    e._timer_emiss = 0
    e._ativo       = true
    return e
end

-- ── Emissão ──────────────────────────────────────────────────

--- Emite `n` partículas imediatamente (ou e.quantidade por padrão).
--- @param e table   Emissor
--- @param n number? Quantidade a emitir (opcional)
function P.emitir(e, n)
    n = n or e.quantidade
    local ps = e._particulas
    for _ = 1, n do
        if #ps >= e.max then break end
        local ang = rndF(e.angulo_min, e.angulo_max)
        local vel = rndF(e.vel_min,    e.vel_max)
        local ox  = e.espalhamento > 0 and rndF(-e.espalhamento, e.espalhamento) or 0
        local oy  = e.espalhamento > 0 and rndF(-e.espalhamento, e.espalhamento) or 0
        ps[#ps + 1] = {
            x   = e.x + ox,
            y   = e.y + oy,
            vx  = cos(ang) * vel,
            vy  = sin(ang) * vel,
            t   = 0,                             -- tempo vivido
            tv  = rndF(e.vida_min, e.vida_max),  -- tempo de vida total
        }
    end
end

-- ── Atualização ──────────────────────────────────────────────

--- Atualiza o emissor e todas as suas partículas.
--- @param e  table  Emissor
--- @param dt number Delta time (segundos)
function P.atualizar(e, dt)
    if not e._ativo then return end

    -- Emissão contínua
    if e.continuo then
        e._timer_emiss = e._timer_emiss - dt
        if e._timer_emiss <= 0 then
            e._timer_emiss = e.intervalo
            P.emitir(e)
        end
    end

    -- Atualiza cada partícula
    local ps   = e._particulas
    local grav = e.gravidade
    local atr  = e.atrito
    local i    = 1
    while i <= #ps do
        local p = ps[i]
        p.t  = p.t + dt
        if p.t >= p.tv then
            -- remove partícula morta (swap com a última)
            ps[i] = ps[#ps]
            ps[#ps] = nil
        else
            -- física simples
            p.vy = p.vy + grav * dt
            if atr > 0 then
                local f = 1 - atr * dt
                if f < 0 then f = 0 end
                p.vx = p.vx * f
                p.vy = p.vy * f
            end
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            i = i + 1
        end
    end
end

-- ── Desenho ──────────────────────────────────────────────────

--- Desenha todas as partículas do emissor usando a API Tupi.
--- Chame dentro de _desenhar().
--- @param e table Emissor
function P.desenhar(e)
    local ps   = e._particulas
    local ci   = e.cor_ini
    local cf   = e.cor_fim
    local ti   = e.tamanho_ini
    local tf   = e.tamanho_fim
    local fmt  = e.formato

    for _, p in ipairs(ps) do
        local prog = p.t / p.tv          -- 0 → 1 (progresso de vida)
        local cor  = lerpCor(ci, cf, prog)
        local tam  = lerp(ti, tf, prog)
        if tam < 0.5 then tam = 0.5 end

        Tupi.cor(cor[1], cor[2], cor[3], cor[4])

        local px = floor(p.x)
        local py = floor(p.y)

        if fmt == "quadrado" then
            local meio = floor(tam * 0.5)
            Tupi.retangulo(px - meio, py - meio, tam, tam)
        elseif fmt == "pixel" then
            Tupi.retangulo(px, py, 1, 1)
        else  -- "circulo" (padrão)
            local raio = tam * 0.5
            local segs = raio > 4 and 12 or 8
            Tupi.circulo(px, py, raio, segs)
        end
    end

    -- Restaura cor branca opaca após desenhar
    Tupi.cor(1, 1, 1, 1)
end

-- ── Utilidades ───────────────────────────────────────────────

--- Move o ponto de origem do emissor.
function P.mover(e, x, y)
    e.x = x
    e.y = y
end

--- Retorna quantas partículas estão vivas.
function P.total(e)
    return #e._particulas
end

--- Remove todas as partículas vivas do emissor.
function P.limpar(e)
    e._particulas  = {}
    e._timer_emiss = 0
end

--- Pausa/retoma emissão contínua sem apagar as partículas.
function P.pausar(e)  e._ativo = false end
function P.retomar(e) e._ativo = true  end

--- Destroça: para e limpa.
function P.destruir(e)
    P.pausar(e)
    P.limpar(e)
end

-- ── Presets prontos ──────────────────────────────────────────
-- Atalhos para efeitos comuns. Retornam uma tabela de config
-- que pode ser passada diretamente para P.novo().

--- Fogo (emissor para cima, laranja → vermelho)
function P.preset_fogo(x, y, intensidade)
    intensidade = intensidade or 1
    return P.novo({
        x           = x, y = y,
        quantidade  = floor(6 * intensidade),
        vel_min     = 20,  vel_max    = 50 * intensidade,
        angulo_min  = -math.pi * 0.9,
        angulo_max  = -math.pi * 0.1,
        vida_min    = 0.3, vida_max   = 0.8,
        tamanho_ini = 5,   tamanho_fim = 0,
        cor_ini     = {1.0, 0.85, 0.1, 1.0},
        cor_fim     = {1.0, 0.1,  0.0, 0.0},
        gravidade   = -10,
        continuo    = true,
        intervalo   = 0.04,
        formato     = "circulo",
        espalhamento = 3 * intensidade,
    })
end

--- Explosão (one-shot, não contínua)
function P.preset_explosao(x, y, raio)
    raio = raio or 1
    local e = P.novo({
        x           = x, y = y,
        quantidade  = floor(20 * raio),
        vel_min     = 40 * raio, vel_max = 120 * raio,
        angulo_min  = 0, angulo_max = math.pi * 2,
        vida_min    = 0.4,       vida_max = 0.9,
        tamanho_ini = 5,         tamanho_fim = 0,
        cor_ini     = {1.0, 0.9, 0.3, 1.0},
        cor_fim     = {0.8, 0.1, 0.0, 0.0},
        gravidade   = 40,
        atrito      = 1.5,
        continuo    = false,
        formato     = "circulo",
    })
    P.emitir(e)  -- dispara imediatamente
    return e
end

--- Neve (cai de cima, branco)
function P.preset_neve(largura_tela, y_inicio)
    return P.novo({
        x           = 0, y = y_inicio or -10,
        quantidade  = 3,
        vel_min     = 10, vel_max = 30,
        angulo_min  = math.pi * 0.3,
        angulo_max  = math.pi * 0.7,
        vida_min    = 3.0, vida_max = 6.0,
        tamanho_ini = 2,  tamanho_fim = 2,
        cor_ini     = {1.0, 1.0, 1.0, 0.9},
        cor_fim     = {0.8, 0.9, 1.0, 0.5},
        gravidade   = 5,
        continuo    = true,
        intervalo   = 0.12,
        formato     = "circulo",
        espalhamento = largura_tela or 128,
    })
end

--- Faíscas / estrelas (dispara para todos os lados)
function P.preset_faiscas(x, y)
    local e = P.novo({
        x           = x, y = y,
        quantidade  = 12,
        vel_min     = 60, vel_max = 140,
        angulo_min  = 0, angulo_max = math.pi * 2,
        vida_min    = 0.3, vida_max = 0.7,
        tamanho_ini = 2,   tamanho_fim = 0,
        cor_ini     = {1.0, 1.0, 0.6, 1.0},
        cor_fim     = {1.0, 0.5, 0.0, 0.0},
        gravidade   = 80,
        atrito      = 0.8,
        continuo    = false,
        formato     = "pixel",
    })
    P.emitir(e)
    return e
end

--- Mágica / cura (sobem, desvanecem, paleta PICO-8 roxa/lilás)
function P.preset_magica(x, y)
    return P.novo({
        x           = x, y = y,
        quantidade  = 2,
        vel_min     = 10, vel_max = 35,
        angulo_min  = -math.pi * 0.9,
        angulo_max  = -math.pi * 0.1,
        vida_min    = 0.8, vida_max = 1.5,
        tamanho_ini = 3,   tamanho_fim = 0,
        cor_ini     = {0.8, 0.5, 1.0, 1.0},
        cor_fim     = {0.3, 0.1, 0.8, 0.0},
        gravidade   = -15,
        atrito      = 0.5,
        continuo    = true,
        intervalo   = 0.08,
        formato     = "circulo",
        espalhamento = 4,
    })
end

-- ── Gestor global (opcional) ─────────────────────────────────
-- Para quem quer gerenciar múltiplos emissores de uma vez:
--
--   P.G.adicionar(meu_emissor)
--   P.G.atualizar(dt)   -- no _rodar()
--   P.G.desenhar()      -- no _desenhar()
--   P.G.remover(meu_emissor)

P.G = (function()
    local lista = {}
    local G = {}

    function G.adicionar(e)
        lista[#lista + 1] = e
        return e
    end

    function G.remover(e)
        for i, v in ipairs(lista) do
            if v == e then
                table.remove(lista, i)
                return
            end
        end
    end

    function G.atualizar(dt)
        for _, e in ipairs(lista) do
            P.atualizar(e, dt)
        end
    end

    function G.desenhar()
        for _, e in ipairs(lista) do
            P.desenhar(e)
        end
    end

    function G.limpar_todos()
        for _, e in ipairs(lista) do P.limpar(e) end
        lista = {}
    end

    function G.total()
        local n = 0
        for _, e in ipairs(lista) do n = n + #e._particulas end
        return n
    end

    return G
end)()

-- ────────────────────────────────────────────────────────────
return P