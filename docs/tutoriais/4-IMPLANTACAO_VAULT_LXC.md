# Implantação e Configuração do HashiCorp Vault (LXC)

O laboratório IaC do IFRO pauta-se no princípio corporativo de proteção de credenciais. A orquestração das instâncias via Terraform e Ansible não deve trafegar senhas ou chaves em "texto plano" dentro dos repositórios locais. Para assegurar esta governança de chaves (DevSecOps), foi adotado o **HashiCorp Vault**.

Este documento detalha a criação e arquitetura da máquina contêiner responsável por armazenar este serviço.

---

## 1. Criação do Contêiner LXC Administrativo (O Cofre)

O servidor Vault exige altíssima proteção estrutural e não é gerado via automação das "máquinas de alunos". Ele é uma infraestrutura *"Core"* fixa do laboratório e gerencia toda a segurança.

No ambiente de testes (nó `pve`), subimos inicialmente o cofre garantindo que as premissas de performance e de isolamento pudessem ser suportadas. O contêiner de suporte ao cofre possui as seguintes especificações base:

### 1.1 Especificações do Proxmox LXC

Conforme evidenciado pelos resultados do painel de infraestrutura, os parâmetros emulados foram definidos de forma robusta e restritiva:

* **Node Operante:** `pve` (O *host* principal do nosso cluster ou teste de bancada).
* **Tipo Contêiner:** `Unprivileged: Yes` 
  * *Justificativa:* Fundamental para ferramentas de guarda de senha. Contêineres sem privilégio (*unprivileged*) convertem o usuário `root` dentro do contêiner em um usuário comum e restrito na visão do S.O do Proxmox *Host*, blindando o servidor contra técnicas de invasão ou fugas do contêiner (*container escape*).
* **Processamento (vCPU):** 2 CPU(s)
  * *Justificativa:* Poder computacional para sustentar centenas de requisições de criptografia pesada vindas das conexões do Terraform no momento em que os painéis web liberam as máquinas dos alunos.
* **Memória Instalada:** 4.00 GiB
  * *Justificativa:* O HashiCorp Vault baseia-se pesadamente em *Locks* e arquivos em RAM (*In-Memory*) visando a vedação do cofre e respostas automáticas agudas. Aumentar a faixa original (geralmente ~1GB) para 4GB garante uma tolerância máxima no caso de turmas completas requisitando acesso no mesmo minuto do relógio.

---

## 2. Instalação do Serviço Vault (Via Repositório Oficial)

A base fisiológica (Hardware/LXC) foi validada operando como esperado (`CPU usage 0.00%`). O passo seguinte consiste na implementação sistêmica do serviço através da instalação do pacote oficial do HashiCorp de forma controlada. 

Foi escolhida a instalação via Gerenciador de Pacotes (APT) utilizando o repositório da HashiCorp que resguarda maior estabilidade na manutenção (S.O baseado em debian).

### 2.1 Preparação de Bibliotecas Criptográficas
No terminal principal do contêiner (`root@vault`), instalamos primeiramente os pacotes GNU Privacy Guard para ser possível certificar a autenticidade matemática dos pacotes da fabricante:

```bash
apt install -y gnupg 
```

### 2.2 Importação das Chaves e Repositório GPG da HashiCorp
A chave pública GPG foi baixada, desarmada em um anel isolado e o repositório oficial (Branch *bookworm*) foi alimentado na lista global do APT: 

```bash
# Obtenção da Assinatura:
wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Configuração da Source List (Debian/Bookworm):
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" | tee /etc/apt/sources.list.d/hashicorp.list
```

### 2.3 Execução da Instalação e Auto-Geração de Certificados
Por fim, executamos a atualização da lista base e a instalação definitiva no sistema de arquivos:

```bash
apt update
apt install -y vault
```

**Resultados do Ambiente (Saída Consolidada):**
A instalação (pacote `vault_1.21.4-1_amd64.deb` possuindo cerca de 171MB compactado) extraiu os binários fundamentais para execução robusta. Por ser um ambiente restritivo corporativo, a rotina oficial de instalação pré-configurou nativamente as chaves e os certificados SSL/TLS self-signed garantindo encriptação de tráfego, o que é demonstrado na saída do console: 
> *Vault TLS key and self-signed certificate have been generated in '/opt/vault/tls'.*

---

## 3. Inicialização e Configuração do Cofre (Modo Dev - Orientação e Testes)

O núcleo de senhas do projeto já habita integralmente o laboratório virtual. Após a instalação, procedemos com a inicialização do serviço. Para o escopo inicial do laboratório e testes de conectividade da API, o servidor foi primeiramente configurado e iniciado em modo de desenvolvimento (`-dev`).

> [!WARNING]
> O modo de desenvolvimento (`-dev`) roda inteiramente em memória (RAM) e inicia destrancado (*unsealed*) com uma única chave mestra. Este modo perde todos os dados a cada reinicialização, sendo estritamente voltado para validação em ambientes fechados de estudo e **não** deve ser utilizado em produção corporativa sem planejamento sólido de persistência de dados.

### 3.1 Execução do Servidor (Modo Dev)

No terminal do contêiner, o serviço foi invocado apontando para o endereço IP fixado da interface de rede (por exemplo, `10.7.0.31`):

```bash
vault server -dev -dev-listen-address="10.7.0.31:8200"
```

A saída do console confirmou a inicialização bem-sucedida, a versão operacional (`Vault v1.21.4`) e o armazenamento temporário restrito em memória (`Storage: inmem`):

```text
==> Vault server configuration:

Administrative Namespace: 
             Api Address: http://10.7.0.31:8200
                     Cgo: disabled
         Cluster Address: https://10.7.0.31:8201
                 Storage: inmem
                 Version: Vault v1.21.4, built 2026-03-04T17:40:05Z
```

### 3.2 Verificação de Status do Cluster (Modo Dev)

Para confirmar a integridade do cofre provisório, exportamos a variável de ambiente base e checamos o estado operacional do serviço:

```bash
export VAULT_ADDR='http://10.7.0.31:8200'
vault status
```

O comando retornou o panorama da infraestrutura, demonstrando que o Vault encontra-se plenamente inicializado e destrancado (*unsealed*), retornando `Storage Type: inmem`.

---

## 4. Inicialização do Cofre (Persistência Ativada - Oficial)

Uma vez compreendido o comportamento do Vault e validada a conectividade de testes, avançamos para a implementação definitiva. Como o modo `-dev` anula todos os dados a cada reinicialização (resetando políticas, engines e tokens), configuramos o modo persistente padrão baseado em disco para assegurar a governança contínua das chaves do IaC.

### 4.1 Arquivo de Configuração (vault.hcl)

Definimos as políticas de porta, protocolo e persistência alterando o manifesto principal. 

* **Alerta sobre o `mlock`**: Por padrão, o Vault tenta alocar de forma bloqueada na RAM todos os segredos usando a syscall `mlock()`, impedindo desvios para o `swap`. Contudo, de dentro de um contêiner LXC essa ação pode esbarrar em restrições de Kernel gerando o erro de inicialização `Failed to lock memory`. Para este projeto estritamente laboratorial, a rotina foi contornada via opção `disable_mlock = true`.

Criamos o arquivo de configuração `vault.hcl` com as diretrizes de armazenamento físico (`file`):

```hcl
disable_mlock = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

api_addr = "http://10.7.0.31:8200"
cluster_addr = "http://10.7.0.31:8201"

ui = true
```

* **Storage:** Substitui o modo temporário `inmem` por uma pasta local hospedada do contêiner (`/vault/data`), resguardando as gravações permanentemente.
* **Listener / API:** Libera a escuta HTTP na porta `8200` direcionando as transmissões do cluster dentro da nossa rede de gerência de laboratório.

### 4.2 Execução do Servidor com Configuração Customizada

Com as declarações criadas, disparamos a inicialização definitiva do sistema repassando o parâmetro de carga:

```bash
vault server -config=vault.hcl
```

### 4.3 Inicialização Gráfica e Deslacramento (*Unseal*)

Ao rodar pelo perfil canônico (persistente), o Vault carrega como protocolo de defesa o isolamento nato. Ele nascerá selado (*Sealed*) e desconfigurado.

Acessando o painel via navegador (`http://10.7.0.31:8200`), seremos direcionados para a etapa primária do Vault: o fornecimento das chaves mestras necessárias para a Inicialização (*Init*).

![Tela de Destrancamento Inicial do Vault](../../imagens/vault/vault-unsell.png)

Confirmando os campos conforme a arquitetura de fragmentação de senhas eleita para as **Unseal Keys**: 

![Geração e Download das Chaves do Vault](../../imagens/vault/vault-keys.png)

As chaves geradas e baixadas (no pacote JSON ou individualmente) formam o cofre da aplicação. O Vault entra em transição solicitando as recém-criadas frações (*Key Portions*) para desbloqueio da camada protetora.

![Input do Vault Unseal](../../imagens/vault/vault-open.png)

### 4.4 Acesso Oficial à Interface Gráfica (Web UI)

Satisfeite o destrancamento sistêmico, entramos na barreira de login convencional. Inserimos o *Root Token* obtido na fase de geração de chaves para autenticação administrativa:

![Tela de Login do Vault](../../imagens/vault/vault-login.png)

E com o login confirmado, consolidamos a integração destas ferramentas com as primeiras políticas e segredos na prancheta de monitoramento (*Dashboard*), coroando a guarda criptografada exigida nos fluxos automatizados do nosso IaC.

![Dashboard do Vault](../../imagens/vault/vault-dashboard.png)

---

## 5. Criação da Secrets Engine (KV) e Armazenamento do Primeiro Segredo

Com o Vault instanciado e operante, o próximo passo é criar um motor de segredos (*Secrets Engine*) focado em registros no formato chave-valor (KV). Nele, guardaremos as credenciais confidenciais da nossa infraestrutura (como o *API Token* do Proxmox) e as deixaremos isoladas do Terraform.

Abaixo, listamos o procedimento completo para a criação da base e do primeiro segredo por dentro da Interface Gráfica:

1. **Acesso Guiado:** Na tela inicial ativa do Vault (`http://10.7.0.31:8200/ui/vault/dashboard`), dirija-se à barra lateral ou interface principal e clique em **"Secrets Engines"**.
2. **Habilitar Nova Base:** Encontre e clique no botão **"Enable new engine"**.
3. **Escolha o Formato KV:** Dentre as opções na categoria genérica, escolha o ícone **"KV"** (*Key-Value*) e avance.
4. **Definição de Rota (Path):** Na página de configuração, clique no campo `Path` e defina um caminho amigável e referencial. Pode-se utilizar o nome **`senhas`**.
5. **Ativação:** Finalize este nível clicando em **"Enable engine"**.

### 5.1 Populando a Engine e Cadastrando a Chave do Proxmox

Agora que a área lógica (`senhas/`) foi ativada, geramos o primeiro bloco secreto:

1. Estando dentro do escopo do menu `senhas`, clique em **"Create secret"**.
2. **Path Específico do Segredo:** Selecione o campo `Path for this secret` e restrinja a funcionalidade preenchendo o identificador, por exemplo: **`proxmox`**. Isso forjará a rota completa `senhas/proxmox`.
3. **Preenchimento dos Dados:**
   * Clique no campo `key` e digite/cole a nomenclatura exata que referenciará e identificará a senha. (Exemplo: O ID da *key* ou o nome global que o Terraform consumirá).
   * No campo ao lado do valor agregado (*Value*), cole ( `ctrl` + `v` ) publicamente a sua *string* de credencial longa correspondente ao identificador no Proxmox.
4. **Salvamento:** Finalize a submissão clicando no botão **"Save"**.

> O ambiente está pronto e a infraestrutura blindada. O Terraform passará a invocar conexões API ao Vault e, requisitando acesso ao endereço `senhas/proxmox`, retornará as predefinições de variáveis e instanciará as máquinas nos laboratórios operacionais integralmente "por debaixo dos panos"!
