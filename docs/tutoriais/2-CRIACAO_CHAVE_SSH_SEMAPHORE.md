# Geração da Chave SSH para o Semaphore

A criação de uma chave SSH atemporal e de escopos definidos para o usuário `semaphore` é um dos passos primordiais da documentação. Essa chave é essencial para a automação de configurações e rotinas do painel **Semaphore** contra sua infraestrutura. 

Posteriormente, a parte pública dessa chave será anexada ao *template* LXC base do Proxmox, servindo de portal de confiança para que o Semaphore interaja com todos os containers/VMs automatizadas.

🔑 **💡 Como funciona (Simples)**

A lógica das chaves é dissociada da máquina original. Logo, **a chave SSH não precisa ser gerada dentro do Semaphore**. Ela só precisa existir. Você então fornecerá:
* 🔐 **Chave Privada**: Vai no ambiente do Semaphore (no Key Store).
* 🔓 **Chave Pública**: Vai nos servidores e *templates* alvo (LXC/VM).

---

## ✅ 🔧 Passo a passo de criação

**1️⃣ Gerar a chave (em qualquer sistema Linux)**

Você pode realizar este procedimento no *terminal* do seu PC, num servidor auxiliar ou numa VM estrita de administração. O importante é o painel do administrador. Digite o seguinte comando para gerar localmente a credencial em criptografia Ed25519:

```bash
ssh-keygen -t ed25519 -C "semaphore"
```

![Geração da Chave SSH](../../imagens/ssh/ssh-generate.png)

**2️⃣ Tratando dos Arquivos Gerados**

Finalizado o procedimento (geralmente as chaves ficarão armazenadas por default no caminho `~/.ssh/`), você obterá um par de dados:

* O arquivo da **chave privada** (`id_ed25519`): É esse conteúdo confidencial que você entregará à *Key Store* do Semaphore via painel.
* O arquivo da **chave pública** (`id_ed25519.pub`): É a identificação estrita que os servidores (LXC/Proxmox) passarão a reconhecer e autorizar nas rotinas IaC.

![Par de chaves SSH](../../imagens/ssh/ssh-semaphore.png)
