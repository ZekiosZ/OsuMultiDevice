# 🌀 OsuMultiDevice — Transforme seu celular em um tablet ou mini Teclado para PC!

Este é um projeto pessoal que conecta seu **celular Android** a um **PC com Windows**,
permitindo usá-lo como **mouse/tablet digital** e **teclado virtual** — ideal para jogos rítmicos como *osu!* ou *Fnf*.

Infelizmente no momento o mesmo so e compativel com versões web dos mesmos jogos por questões de anticheats e sobreposições dos mesmos
---
##  Link Para Download
Baixe os arquivos aqui `Download`([link direto](https://github.com/ZekiosZ/OsuMultiDevice/releases/tag/New)).

## 🎯 Funcionalidades

- Envia toques e cliques em tempo real via rede local (UDP)
- Modos:
  - 🖱️ Tablet/Mouse
  - ⌨️ Teclado (Z/X, Z/X/C/V)
- Comunicação leve e rápida (sem servidor intermediário)
- Modo automático de descoberta (não precisa digitar IP)
- Layout otimizado em **modo paisagem**
- Compatível com **USB Tethering** ou **Wi-Fi**

---

## 🧠 Tecnologias Utilizadas

| Componente | Linguagem / Framework | Função |
|-------------|----------------------|---------|
| App Mobile  | Flutter (Dart)       | Interface e controle via touch |
| Agente PC   | C# (.NET 8)          | Recebe e traduz os comandos em entradas de mouse/teclado |
| Protocolo   | UDP + JSON           | Comunicação leve e em tempo real |

---

## ⚙️ Instalação e Uso

### 🪟 No PC (Agente)
1. Baixe o agente
2. Extraia e execute **OsuMultiDevice.Agent.exe** (ele ficará ouvindo na porta 8765).
3. Mantenha o terminal aberto — ele mostra logs dos comandos recebidos e mantem o server rodando.

### 📱 No Android (App)
1. Baixe e instale o arquivo **OsuMultiDevice.apk**.
2. Conecte o celular e o PC na **mesma rede** ou via **USB Tethering**.
3. Abra o app — ele detectará o agente automaticamente.
4. Escolha o modo “Tablet/Mouse” ou “Keyboard”.
5. Divirta-se 🎮

---
### ℹ️ Aviso
Este projeto foi desenvolvido apenas como um exercício pessoal e para portfólio.
Não há fins comerciais, e o uso do código é de livre estudo.
