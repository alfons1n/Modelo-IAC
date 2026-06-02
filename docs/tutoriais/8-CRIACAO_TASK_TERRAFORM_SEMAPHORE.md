# Tarefa de Automatização Terraform no Semaphore UI (Foco em Contêineres)

Nesta primeira etapa da nossa jornada de Infraestrutura como Código (IaC), o foco central é usar a interface gráfica para configurar uma **tarefa de automatização do Terraform no Semaphore UI**. O objetivo primordial deste passo é primeiramente "criar a infraestrutura" (provisionamento dos contêineres). 

Apenas após gerarmos a arquitetura estrutural como código, partiremos futuramente para a criação de rotinas no *Ansible* focadas em automatizar as configurações internas de cada máquina nova.

Nesta etapa preparatória de rede, criaremos a automação para testar a comunicação com a API do Proxmox e baixar o nosso código armazenado no diretório `terraform-teste/` diretamente do nosso repositório no GitHub.

> **Aviso de Pré-requisito:**  
> Para que os passos abaixo funcionem corretamente, é estritamente necessário ter concluído todas as parametrizações detalhadas no documento anterior: [CONFIGURACAO_TERRAFORM_SEMAPHORE.md](../../docs/manuais/CONFIGURACAO_TERRAFORM_SEMAPHORE.md).

---

## Por que utilizar a Interface Gráfica (GUI) em vez do Shell?

É muito importante ressaltar que o Terraform possui uma interface nativa poderosa baseada na linha de comando (Bash/Shell). No entanto, a ideia central deste laboratório de TCC (e de ambientes corporativos modernos) é justamente abstrair a complexidade. 

Damos preferência ao uso da **interface gráfica do Semaphore** por promover melhorias diretas na **Governança de TI**:
1. O ambiente passa a ter opções de auditoria, onde podemos **visualizar ativamente o fluxo e histórico** de cada processo e alteração aprovada ou negada.
2. Diminui consideravelmente a curva de aprendizado, permitindo que a execução do lab se dissemine facilmente sem a necessidade de os operadores decorarem inúmeros parâmetros textuais baseados em Shell.
3. Atualmente, os servidores e equipamentos possuem forte poder computacional. O custo indireto de hospedar um painel Web como o Semaphore é mínimo em comparação ao ganho com organização visual e escalabilidade sem sacrifícios de desempenho.

---

## Passo 1: Configuração das Variáveis de Ambiente no Semaphore

Antes de criar a diretriz da tarefa (`Task`), há algo muito importante para ajustar. Todo o código Terraform depende de dados passados externamente para conseguir efetuar cálculos ou chaves temporárias para se conectar a outras instâncias. 

Escrever isso tudo através do *Command Line* seria extremamente denso e sujeito a erros humanos (ex: o temido erro de esquecer aspas ou traços). A interface web facilita totalmente a inserção destas variáveis através da área que a plataforma chama de **"Environment"** (`Grupos de Variáveis`). 

*Acesse a seção de Grupos de Variáveis para preparar o terreno:*
![Início e Acesso à Tela das Variáveis de Ambiente](../../imagens/task-terraform/semaphore-variables-terraform.png)

Em seguida, precisamos declarar com cuidado todas as variáveis que exigem preenchimento conforme estabelecido pelo nosso arquivo de variáveis do Terraform (`variables.tf` localizado dento de `terraform-teste/`). 

*Exemplo da listagem das propriedades e apontamentos que devem bater 100% com a codificação criada no arquivo supracitado:*
![Configuração das Variáveis relativas ao Código do Repositório](../../imagens/task-terraform/semaphore-variables-terraform-02.png)

Além das propriedades do ambiente Proxmox (como CPUs e memória), não podemos de forma alguma esquecer da credencial externa responsável por trazer nosso controle de segurança. Precisamos registrar o **Token Privilegiado de Acesso do Vault**, sendo essa a única forma que o código base tem autoridade e porta de comunicação com ele:
![Inserindo credencias do Vault na listagem das variáveis](../../imagens/task-terraform/semaphore-variables-terraform-03.png)

---

## Passo 2: Criando o Modelo Principal (Task Template)

Apenas quando as variáveis, os repositórios (`Repositories`) e chaves do Github (`Key Store`) estão totalmente inseridas e checadas no projeto do Semaphore... podemos finalmente conectar as trilhas! 

O último passo agora é montar o bloco de instrução principal que nós indicaremos para rodar. Vá até o menu e entre na seção de **"Task Templates"** (Modelos de Tarefas). 

![Passo inicial para Acessar e Adicionar a Criação do Modelo](../../imagens/task-terraform/task-terraform-01.png)

Use esse momento para preencher a sua folha de orquestração. Dê nome à rotina para os relatórios, associe a **URL do nosso repositório no Github**, e diga de forma exata para que a inteligência do Semaphore aponte e verifique dentro da pasta `"terraform-teste/"`:

![Associação Final e Interligação do Repositório](../../imagens/task-terraform/task-terraform-02.png)

Neste ponto, nosso processo contínuo (Flow) está completamente amarrado com nossa automação programada, nossos repositórios e nossa infraestrutura de hipervisor. No próprio Semaphore basta apertar `RUN` e observar os resultados refletindo instâncias novas sendo geradas dentro do Proxmox perfeitamente sob os nossos códigos.

---

## Passo 3: Execução e Troubleshooting (O Problema do Cofre)

Acompanhar a execução real é uma etapa valiosa, pois ajuda a lidar com o *troubleshooting* (resolução de problemas) e ressalta importantes decisões arquiteturais que todo engenheiro de IaC deve dominar.

O primeiro teste ao acionarmos a tarefa via Semaphore rendeu bons resultados iniciais. O sistema obteve sucesso tanto no download ("Pull") do repositório no GitHub quanto na inicialização dos provedores (Proxmox / Vault). As variáveis de ambiente foram perfeitamente reconhecidas:

![Sucesso na Inicialização do Terraform](../../imagens/terraform/terraform-log-erro-01.png)  
![Reconhecimento das Variáveis](../../imagens/terraform/terraform-log-erro-02.png)

Mesmo com toda estrutura básica correta, nossa esteira automatizada (pipeline) quebrou ao realizar o `terraform plan`. Nos deparamos com a seguinte mensagem de erro crucial:

```text
Error: failed to lookup token
Code: 503
Errors:
* Vault is sealed
```

![Log de erro exibindo que o Vault estava selado](../../imagens/terraform/terraform-vaut-erro-unsel.png)

**Por que isso acontece?**
No trecho inicial de nossa codificação, especificamos que o Terraform usará a fonte de dados do Vault para construir a variável que contem a senha da API (`data "vault_kv_secret_v2" ...`).
A quebra deste processo demonstra que é **totalmente esperado** que não funcione quando o Vault está "Selado" (bloqueado). Um Vault selado recusa sumariamente qualquer tipo de solicitação de API, logo o Proxmox Provider nem sequer chega a abrir. **Não se trata de um erro de sintaxe, mas sim de uma limitação arquitetural que exige uma decisão.**

### Soluções Arquiteturais Possíveis (Prós e Contras)

Para resolver esse dilema sistêmico, apresentamos alternativas classificadas da melhor para a mais simples:

🥇 **Solução RECOMENDADA (Ideal para Produção / Cloud Nativo)**
> **Auto-Unseal no Vault:** A melhor prática é delegar o destrancamento a um serviço focado nisso (como AWS KMS, Azure Key Vault, GCP KMS ou Transit de outro Vault). Dessa forma, assim que o servidor sobe, ele busca a chave master e atinge plenitude sozinho, garantindo funcionamento ininterrupto de esteiras de CI/CD sem envolver humanos.

🥈 **Solução Intermediária (Ideal para nosso tipo de Laboratório/Estudo)**
> **Unseal via Pipeline (Shell):** Podemos rodar uma *pre-task* ou comando bash direto na nossa automação que destranque o Vault instantes antes de o Terraform rodar.
> ```bash
> export VAULT_ADDR=http://10.7.0.31:8200
> vault operator unseal $VAULT_UNSEAL_KEY
> ```

🥉 **Solução Alternativa (Desacoplando durante o Build)**
> **Leitura de Token Misto:** Modificamos a regra arquitetural usando o Ansible em uma segunda perna do processo para fazer o meio campo do Vault e passamos localmente a variável por CLI via Semaphore: `export PM_API_TOKEN_SECRET=xxx`. O plano de provisionamento não é interrompido.

Considerando os propósitos deste ambiente acadêmico, prosseguimos temporariamente com o método de realizar o desbloqueio (*Unseal*) diretamente na interface gráfica do nosso servidor cofre.

![Acesso à interface para preenchimento da chave de desbloqueio](../../imagens/vault/vault-unsel-terraform.png)  
![Login no Vault após Unseal completado](../../imagens/vault/vault-login.png)

---

## Passo 4: O Fluxo de Sucesso, Planejamento e Aplicação

Com as chaves destrancadas devidamente expostas à API, efetuamos a tentativa novamente. O Terraform leu perfeitamente o Vault, resgatou o Token do Proxmox Provider e declarou que planeja construir as infraestruturas.

![Log de sucesso do ambiente se comunicando após unseal](../../imagens/terraform/terraform-log-sucess-01.png)  
![Leitura efetiva da API confirmada no console](../../imagens/terraform/terraform-log-sucess-02.png)

Abaixo, um extrato condensado evidenciando o momento em que a linguagem demonstra clareza na construção dos 2 contêineres e na conversão da estrutura `for_each`:

```diff
Terraform will perform the following actions:

+ resource "proxmox_lxc" "this" {
    + clone        = "lxc-base-debian13-v1"
    + cores        = 2
    + memory       = 1024
    + hostname     = "aluno-01"
    + start        = true
    + target_node  = "pve-iac"
    + unprivileged = true
    + vmid         = 300
    # ... propriedades de rootfs e redes (dhcp)
  }

+ resource "proxmox_lxc" "this" {
    + clone        = "lxc-base-debian13-v1"
    + hostname     = "aluno-02"
    + vmid         = 301
    # ... repete as definições para o aluno 2
  }

Plan: 2 to add, 0 to change, 0 to destroy.
```

Uma medida de segurança de ambientes de interface automatizada é não iniciar as alterações destrutivas sem a intervenção de um gestor. O fluxo de aprovação requer uma confirmação de "Apply" após validar o plano.

![Aviso do Semaphore solicitando a permissão do Operador para Prosseguir](../../imagens/terraform/terraform-task-status.png)

Assim que fornecido o *Check*, o processo seguiu automaticamente.  
**O resultado final foi o êxito.** O Proxmox atendeu aos comandos da API e validou o funcionamento integralmente como um código (IaC):  

![Log de retorno indicando sucesso na Criação (Completed sucessfully)](../../imagens/terraform/terraform-log-sucess-03.png)  
![Tela inicial do Proxmox demonstrando as duas novas instâncias (300 e 301) em execução](../../imagens/terraform/terraform-task-teste-01.png)

Dessa forma, fica comprovado o domínio funcional da esteira em acoplar **Proxmox + Vault + Terraform + Github + Semaphore** de forma segura, reprodutível e totalmente visível para laboratórios ou grandes projetos estudantis do polo IFRO.
