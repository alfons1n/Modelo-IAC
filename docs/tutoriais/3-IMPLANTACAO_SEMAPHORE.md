# Implantação do Semaphore UI com IaC Integrado (Terraform e Ansible)

O **Semaphore UI** é uma ferramenta de automação robusta orientada à web para o Ansible, e atua como o painel central de execução das rotinas do nosso projeto. Contudo, em nossa arquitetura focada no laboratório de Infraestrutura como Código (IaC), ele foi devidamente estendido para desempenhar papel híbrido processando paralelamente todos os manifestos operacionais orientados ao **Terraform**.

Para garantir este isolamento rigoroso de pacotes (sem instalar o Terraform solto na raiz hospedeira), criamos a nossa própria imagem estendida em múltiplas camadas através do sistema interno de compilação da Docker.

Este manual explana isoladamente os metadados desta customização e seu respectivo deployment.

---

## 1. Carga da Imagem Customizada (`Dockerfile`)

No caminho referencial base para este serviço, gerimos e declaramos o núcleo da compilação mista usando estágios empacotáveis independentes (*Multi-Stage Build*):

```dockerfile
# Stage 1 - Binário do Terraform
FROM hashicorp/terraform:latest AS terraform

# Stage 2 - Semaphore com dependências de produção
FROM semaphoreui/semaphore:v2.17.26

USER root

# Copia o binário do Terraform
COPY --from=terraform /bin/terraform /usr/local/bin/terraform

# Instala pacotes críticos para produção (SSH para o Proxmox, Git para os códigos e Ansible)
RUN apk add --no-cache \
    openssh-client \
    git \
    bash \
    curl \
    ansible \
    python3 \
    py3-pip

# Garante permissões
RUN chmod +x /usr/local/bin/terraform

USER semaphore
```

A inteligência repousa atrelada a copiar (`COPY`) de forma seca somente a base imutável binária principal direto do cofre oficial da HashiCorp (descartando camadas ociosas de OS no *Stage 1*) despejando especificamente seu núcleo para dentro da engrenagem *Alpine Linux* restrita (`v2.17.26`). Na subida, o *Alpine* puxa pacotes adicionais paralelos para chaves seguras e validações estruturais (`openssh-client` e infra base do `ansible`).

---

## 2. Parâmetros da Rede (`docker-compose.yml` e `ENV`)

A instância foi acoplada ao sistema em modo isolado com suporte sólido e persistência referenciado na documentação Compose (`docker-compose.yml`):

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: semaphore-db
    restart: always
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data

  semaphore:
    build: .
    image: semaphore-custom
    container_name: semaphore
    restart: always
    depends_on:
      - postgres
    ports:
      - "3000:3000"
    env_file: .env
    environment:
      SEMAPHORE_DB_HOST: postgres # Nome do serviço acima
      SEMAPHORE_PLAYBOOK_PATH: /iac
    volumes:
      - semaphore_data:/var/lib/semaphore
      - /opt/iac:/iac # Simples e direto

volumes:
  pgdata:
  semaphore_data:
```

Para blindar transações do cofre de login nativamente atrelamos as credenciais primárias geradas (`.env`):

```env
POSTGRES_USER=semaphore
POSTGRES_PASSWORD=CHANGE_ME_POSTGRES_PASSWORD
POSTGRES_DB=semaphore

SEMAPHORE_DB_DIALECT=postgres
SEMAPHORE_DB_HOST=postgres
SEMAPHORE_DB_PORT=5432
SEMAPHORE_DB_USER=semaphore
SEMAPHORE_DB_PASS=CHANGE_ME_POSTGRES_PASSWORD
SEMAPHORE_DB=semaphore

SEMAPHORE_ADMIN=admin
SEMAPHORE_ADMIN_PASSWORD=CHANGE_ME_ADMIN_PASSWORD
SEMAPHORE_ADMIN_NAME=Admin
SEMAPHORE_ADMIN_EMAIL=admin@local
```

### 2.1 Mapeamento e Pontes Chave

* **Construção Automática (`build: .`)**: Essa é a chave do sistema laboratorial. Ao invés da ferramenta espelhar diretamente a web, referenciando do repositório base padrão, ela forçará nativamente primeiro a checagem ou o `build` estático do diretório corrente antes de assumir o processamento da `semaphore-custom`.
* **Montagem `/opt/iac:/iac`**: Esta ponte repassa transparentemente a malha e todas as diretrizes dos laboratórios criadas fora do container diretamente para leitura e operação sem precisar enxertar imagens maciças (Buscáveis em `SEMAPHORE_PLAYBOOK_PATH: /iac`).

---

## 3. Instanciação e *Deployment* (Apoiado pelo Komodo)

Precisamos destacar alguns pontos na instalação da stack Semaphore no Komodo que foi feita na interface gráfica.

🚨 **ATENÇÃO: Contexto do Host vs. Container**  
Os arquivos precisam ser criados **dentro** do container do Komodo (Periphery) e não no LXC nativo do Proxmox. Se o diretório e o arquivo existem, mas o Komodo exibe erro dizendo que estão ausentes, significa que o container não os enxerga. Como você deve interagir via terminal do Periphery, os seguintes passos garantem que os arquivos fiquem acessíveis de dentro da "bolha" da ferramenta.

### 3.1. Criação dos Arquivos Base

Certifique-se de acessar o terminal atrelado ao próprio Komodo e criar os arquivos da stack no diretório referenciado:

```bash
# cd /opt/semaphore
# ls
Dockerfile  compose.yaml
```

#### Tratando Bugs de Encoding e "Missing Files"
Se você encontrar falhas do tipo:
```text
ERROR: Missing files: compose.yaml
ERROR: Failed to read file contents at "/opt/semaphore/compose.yaml"TRACE:
	1: stream did not contain valid UTF-8
```
Isso ocorre porque os arquivos podem conter caracteres invisíveis, lixo residual de cópia ou estarem binários/corrompidos. Para recriar os arquivos de modo seguro como texto puro (UTF-8), utilize o comando `cat <<EOF` no terminal do container para sobrescrever com o conteúdo limpo. Primeiro, repare o arquivo de manifesto:

```bash
cat <<EOF > /opt/semaphore/compose.yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: semaphore-db
    restart: always
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data

  semaphore:
    build: .
    image: semaphore-custom
    container_name: semaphore
    restart: always
    depends_on:
      - postgres
    ports:
      - "3000:3000"
    env_file: .env
    environment:
      SEMAPHORE_DB_HOST: postgres
      SEMAPHORE_PLAYBOOK_PATH: /iac
    volumes:
      - semaphore_data:/var/lib/semaphore
      - /opt/iac:/iac

volumes:
  pgdata:
  semaphore_data:
EOF
```

Em seguida, garanta que o `.env` também esteja sem anomalias:
```bash
cat <<EOF > /opt/semaphore/.env
POSTGRES_USER=semaphore
POSTGRES_PASSWORD=SUA_SENHA_AQUI
POSTGRES_DB=semaphore
SEMAPHORE_DB_DIALECT=postgres
SEMAPHORE_DB_HOST=postgres
SEMAPHORE_DB_PORT=5432
SEMAPHORE_DB_USER=semaphore
SEMAPHORE_DB_PASS=SUA_SENHA_AQUI
SEMAPHORE_DB=semaphore
SEMAPHORE_ADMIN=admin
SEMAPHORE_ADMIN_PASSWORD=SUA_SENHA_ADMIN
SEMAPHORE_ADMIN_NAME=Admin
SEMAPHORE_ADMIN_EMAIL=admin@local
EOF
```

> **Dica**: O uso da tag nativa `EOF` ignora qualquer resíduo anterior e força um *encoding* UTF-8 perfeitamente limpo, sanando travamentos de leitura causados pela engine web do Komodo.

Evite também colar comandos de leitura de imagem (`FROM`, `COPY` ou sintaxes de `Dockerfile`) nos campos de execução ("Commands") em tela, que resultarão num erro do tipo de script Shell `sh`:
```text
sh: 1: FROM: not found
```
No lugar de emular script `sh` as declarações obrigatoriamente devem residir fisicamente dentro do arquivo fixo chamado `Dockerfile` na pasta `/opt/semaphore`.

### 3.2. Configuração Final na Interface Gráfica (UI)

Dessa forma, os problemas mais comuns do *Workspace* e de falha de *encoding* são deixados para trás. Agora volte ao painel web para selar o preenchimento de *Deploy*:

1. **Choose Mode - Files:** Ajuste o modo para a diretriz **Files**, atrelando no **Run Directory** o valor `/opt/semaphore` e deixando **File Path** vazio (ele pegará o `compose.yaml` automaticamente, que recriamos a partir de `.txt` limpo).
   
   ![Opção Files Komodo](../../imagens/docker/komodo-patch.png)

2. **Advanced - Toggle Features:**
   Caso a plataforma gere o diagnóstico `pull access denied for semaphore-custom, repository does not exist`, entenda que a imagem `semaphore-custom` apontada é customizada e dependente de `build` privado; logo o *Docker Hub* não acha uma imagem nativa correspondente pronta.
   
   Para contornar, role as opções e **ative** explicitamente a flag de **Pre Build Images** (`ENABLED`). Opcionalmente, pode inativar a de *Pre Pull Images* caso gere repulsa na interface.
   
   ![Opção Advanced Komodo](../../imagens/docker/komodo-prebuild.png)

   > **💡 Por que isso é obrigatório?** O ecossistema *Docker Compose* original tentaria um `Pull`. Exigindo o bloqueio do *Pre Build*, emulamos perfeitamente e localmente o gatilho `docker compose up -d --build`.

Após salvar e clicar em **Deploy**, o Komodo forçará a construção (o temido build out) perfeitamente livre de instabilidades:

```text
#1 [internal] load local bake definitions
#3 [internal] load metadata for docker.io/semaphoreui/semaphore:v2.17.26
#4 [internal] load metadata for docker.io/hashicorp/terraform:latest
#8 [stage-1 2/4] COPY --from=terraform /bin/terraform /usr/local/bin/terraform (CACHED)
#11 exporting config sha256:339... done
#11 naming to docker.io/library/semaphore-custom:latest done
```

Finalizada a estrutura base, o Compose iniciará os contêineres e pontes referenciadas:

```text
cd /opt/semaphore && docker compose -p semaphore-stack -f compose.yaml --env-file .env up -d

 Network semaphore-stack_default  Creating
 Volume semaphore-stack_pgdata  Creating
 Volume semaphore-stack_semaphore_data  Creating
 Container semaphore-db  Creating
 Container semaphore  Creating
 Container semaphore-db  Starting
 Container semaphore  Starting
```

Você notará rapidamente a estabilizada contínua da stack via Logs da instância no Komodo:

![Logs da Stack Komodo](../../imagens/docker/komodo-stack-services.png)

```text
semaphore     | No additional python dependencies to install
semaphore     | Starting semaphore server
semaphore     | ...Postgres semaphore@postgres:5432 semaphore
semaphore     | Tmp Path (projects home) /tmp/semaphore
semaphore     | Semaphore v2.17.26-3b278d1-1773613270
semaphore     | Interface 
semaphore     | Port :3000
semaphore     | Server is running
```

Dessa forma, confirmamos as aplicações levantadas:

![Containers em Execução Komodo](../../imagens/docker/komodo-containers.png)

Com acesso frontal de operação plenamente funcional:

![Semaphore Login](../../imagens/docker/sempahore-login.png)

Com isso, foi atestado no repositório de Logs e nas telas de acompanhamento que — superados os entraves dos limites do contêiner e de *encoding* UTF-8 —, o **Semaphore** está operacional, interligado (porta `:`**`3000`**) e validando os parâmetros definidos nas variáveis sigilosas base.
