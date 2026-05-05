local Tupi = require("src.Engine.sintaxe")
-- Inicializa a janela com as dimensões de GameBoy (160x144)
Tupi.janela(160, 144, "Meu Jogo", 5.0, false)

local tela_cheia = false
local player = {x=10, y= 10, espelhado = false, direcao = "esquerda", andado = false}
local spr
local px, py = 10, 10
local mapa1
local casa = {
    9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 4, 4, 4, 4, 4, 4, 4, 4, 9,
    9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
}
local vel = 50
local anim_esq

function _iniciar()
    spr = Tupi.imagem("assets/tileset.png")
    player = Tupi.objeto(spr, 10, 10, {larg=8, alt=8, col=0, lin=0})
    anim_esq = Tupi.criarAnim(spr, 8, 8, {0, 1, 2}, {0}, 6, true)
    px, py = 10, 10
    mapa1 = Tupi.mapc("assets/tileset.png", 8, 8, 10, 10)
    Tupi.mapa(mapa1, casa)
    Tupi.pixelSnap(false)
end

function _rodar()
    if Tupi.pressionou("f11") then 
        tela_cheia = not tela_cheia
        Tupi.telaCheia(tela_cheia, true) 
    end
    if Tupi.pressionou("esc") then Tupi.fechar() end
    local dx, dy = 0, 0
    player.andado = false
    if Tupi.botao("w") then dy = dy - 1; player.direcao = "cima" ; player.andado = true end
    if Tupi.botao("s") then dy = dy + 1; player.direcao = "baixo"; player.andado = true end
    if Tupi.botao("a") then dx = dx - 1; player.espelhado = false; player.direcao = "esquerda"; player.andado = true end
    if Tupi.botao("d") then dx = dx + 1; player.espelhado = true ; player.direcao = "direita" ; player.andado = true end
    if player.andado == true then 
        Tupi.tocarAnim(anim_esq, player, 1)
    elseif player.andado == false then 
        Tupi.pararAnim(anim_esq, player, 0, 1)
    end
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx = dx / len
        dy = dy / len
    end
    local mov = vel * Tupi.dt()
    px = px + dx * mov
    py = py + dy * mov
    Tupi.espelhar(player, player.espelhado, false)
    Tupi.posicionar(player, px, py)
end

function _desenhar()
    cls(1)
    Tupi.mapd(mapa1, 1)
    Tupi.draw(player)
end

Tupi.rodar()
