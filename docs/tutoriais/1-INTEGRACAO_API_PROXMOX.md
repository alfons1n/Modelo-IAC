# Integração e Configuração da API do Proxmox para Terraform

Este documento detalha o processo prático realizado para interligar as requisições autenticadas do Terraform ao cluster Proxmox (conforme o modelo arquitetônico IaC desenhado e estruturado no diagrama oficial do projeto). 

A fundamentação e os scripts de apoio do procedimento baseiam-se no roteiro técnico do repositório de Felipe Padilha.

---

## 1. Gerenciamento de Identidade (Conta da API)

Nos preceitos do DevSecOps demonstrados no "Diagrama IaC 2", o *Terraform* jamais utilizará a credencial `root@pam` para escalar instâncias. Precisávamos parametrizar uma chave API restrita com permissões exclusivas de provisionamento.

### 1.1 Criação do Usuário Dedicado
Usando a padronização baseada no artigo técnico, validamos a criação de um profile de API no nosso ambiente de testes rodando Proxmox v9. Na linha de comando do host Proxmox, executamos:

```bash
root@pve:~# wget https://raw.githubusercontent.com/padilhafe/scripts/refs/heads/main/proxmox/terraform_user.sh
root@pve:~# chmod +x terraform_user.sh
root@pve:~# ./terraform_user.sh
```

**Saída/Resultado da Validação no Ambiente de Testes**:
O script detectou corretamente a *major version* (v9) do servidor virtualizador, definiu os privilégios modernos e gerou a Role e a ACL da conta `terraform-prov@pve`. Ao final, a execução obteve o seguinte retorno exibindo os parâmetros do token no console:

```text
[INFO] Detected Proxmox major version: 9
[INFO] Usando lista de privilégios para Proxmox v9+
[INFO] Criando role 'TerraformProv'...
[INFO] Criando usuário 'terraform-prov@pve' (sem senha)...
[INFO] Associando role 'TerraformProv' ao usuário 'terraform-prov@pve' na rota '/'.
[INFO] ACL aplicada.
[WARN] Não consegui extrair automaticamente o token secreto. Aqui está a saída completa:
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ meu token                            │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":"0"}                      │
├──────────────┼──────────────────────────────────────┤
│ value        │ minhachave                           │
└──────────────┴──────────────────────────────────────┘
```

### 1.2 Exportação do Token de Comunicação para o Terraform
Acessando as informações da tabela gerada (onde `full-tokenid` é a identidade e `value` é a senha secreta definitiva), o administrador as insere como variáveis de ambiente na controladora, permitindo requisições autenticadas:

```bash
# Setando o Token e a Secret obtidos no ambiente de testes
export PM_API_TOKEN_ID="meu token"
export PM_API_TOKEN_SECRET="minhachave"
```

> **Nota:** Dentro da fase avançada desenhada para nossa arquitetura, em vez de exportar manualmente em um computador ou servidor, essa secret será inserida e gerida de forma invisível via **HashiCorp Vault**, e configurada diretamente nas rotinas nativas do **Semaphore**, assegurando um fluxo automatizado auditável e blindado.

---

## 2. Preparação do Proxmox para VMs (Apenas Documentação - Modelos Cloud-Init)

> **⚠️ AVISO IMPORTANTE:**
> A prioridade e foco de implantação deste momento do laboratório são os **containers nativos LXC** (acesse o documento específico `CRIACAO_TEMPLATE_LXC_PROXMOX.md` recém-criado).
>
> Contêineres LXC **não** possuem suporte orgânico ao Cloud-Init da mesma maneira que as Máquinas Virtuais (VMs). **Portanto, esta Etapa 2 abaixo não será implementada neste momento**. Ela será mantida unicamente como forma de documentação para embasar demandas futuras caso o provisionamento isolado *KVM* surja nas aulas.

Para que o Terraform consiga multiplicar instantaneamente Máquinas Virtuais robustas, o Proxmox precisa conter "Imagens Base" (Templates Cloud-Init). Estas imagens substituem a arcaica instalação ISO padrão em KVMs, permitindo a injeção instantânea de configurações (como rede DHCP e ssh) direto no primeiro ciclo de *boot*.

### 2.1 Obtenção do Script de Automação VM
Acessando o shell (CLI) diretamente do servidor Proxmox, o utilitário de geração de imagens Cloud-Init pode ser baixado:

```bash
# Baixa o script direto para o nó gerenciador
wget https://raw.githubusercontent.com/padilhafe/scripts/refs/heads/main/proxmox/criar_imagens_cloud_init.sh
```

### 2.2 Customização e Adaptação das Variáveis
Antes de rodar, efetua-se a edição do script (`nano criar_imagens_cloud_init.sh`) adequando as premissas estruturais ao parque laboratorial:

- **`VM_BRIDGE="vmbr0"`**: Aponta para a ponte principal de comunicação virtual do host.
- **`CLOUD_INIT_IP="dhcp"`**: IP dinâmico gerenciado pela rede prática (alinhando-se aos playbooks do projeto).
- **`VM_TAG="0"`**: Corrigido para a tag de tráfego (`0` desativa *VLAN virtual*).
- **`CLOUD_INIT_USER` / `PASSWORD`**: Definida com a credencial institucional oficial do ambiente.

### 2.3 Execução Contínua no Cluster
Conferidos os parâmetros, o script pode ser rodado para forjar os templates virtuais pesados:

```bash
chmod +x criar_imagens_cloud_init.sh
./criar_imagens_cloud_init.sh
```

**Resultado Teórico:** O script automatiza o *download* das imagens nativas oficiais (Ubuntu/Debian com `.img` ou `.qcow2`), destrincha-os sobre volumes de armazenamento virtuais e forja essas bases como Templates utilitários (ex: IDS 9000), garantindo uma multiplicação baseada perfeitamente no *IaC Cloud-Init*.

---

## 3. Resultados Operacionais

A base invertida para a Etapa 1 ativou prontamente as diretrizes indispensáveis para a fluência laboratorial:

1. **Ciclo Autenticado Operante:** Todo comando do Terraform passa a ir e voltar pelo canal *Web Request RestAPI* (`https://[ip-proxmox]:8006/api2/json`) usando a conta submissa criada (`terraform-prov`). Fica garantida a rastreabilidade e blindada a hierarquia que o diagrama solicitou, não quebrando a segurança de senhas absolutas.
2. **Separação Estrutural de Demandas:** Com as fundações prioritárias redirecionadas ao **LXC** (agilidade), temos os alicerces dos papéis de Cloud-Init salvos nas matrizes documentais acima, permitindo escalar e abraçar o formato clássico VM caso as dependências *nested virtualization* no futuro superem os containers nativos.
