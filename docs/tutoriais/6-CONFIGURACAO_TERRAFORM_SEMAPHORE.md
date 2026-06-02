# Configuração do Terraform no Semaphore (Integração com GitHub Privado)

Nosso projeto de infraestrutura como código (IaC) compartilha intimamente dos conceitos e fundamentos da esteira **DevOps**. Sendo assim, o primeiro e mais vital passo prático antes de dispararmos comandos na infraestrutura é estabelecer um repositório versionável para o código Terraform. Dessa forma, alcançamos flexibilidade absoluta, controle do histórico de mudanças estruturais e rastreabilidade total.

Neste guia, passaremos pelo processo de inicialização de um repositório teste, a geração de credenciais seguras em nuvem e a ponte final dele com o nosso painel de gerenciamento matriz, o Semaphore.

---

## 1. Criação e Versionamento (GitHub Desktop)

Para facilitar a gestão das esteiras de Commits, adotamos e utilizamos interativamente o **GitHub Desktop**, que pode ser baixado e atrelado gratuitamente no ecossistema através do link oficial: [https://desktop.github.com/download/](https://desktop.github.com/download/).

1. Após instalar o utilitário, instanciamos a criação de um repositório em diretório novo, batizado de `lab-zero-terraform-teste`. Este repositório assumirá a ponta dos testes reais da integração do kit de ferramentas da HashiCorp com a nossa infraestrutura e Proxmox.
   
   ![Criação do Repositório no GitHub Desktop](../../imagens/terraform/terraform-github-new.png)

2. Trabalhando no diretório do projeto nativo pelo *VS Code*, migramos e copiamos todo o conteúdo experimental que antes residia na nossa pasta crua (`terraform-teste`) para o novíssimo diretório embutido na malha de acompanhamento do git.
   
   ![Cópia dos Arquivos Terraforms Base](../../imagens/terraform/terraform-files-teste.png)  
   ![Visão Estrutural do VS Code](../../imagens/terraform/terraform-vscode.png)

3. Após salvarmos e consolidarmos os manifestos migrados, firmamos nosso primeiro grande **Commit** na interface da ferramenta. Imediatamente após, subimos o material via *Publish repository*, com uma única regra intransponível: mantê-lo blindado com o gatilho "Private" ativado. Nossa base IaC é confidencial e não deve ficar pública na nuvem.
   
   ![Realizando Commit GitHub Desktop](../../imagens/terraform/terraform-teste-commit.png)  
   ![Marcação de Visibilidade Privada](../../imagens/terraform/terraform-teste-upload-private.png)  
   ![Visualizando Push na Ferramenta](../../imagens/terraform/terraform-teste-upload.png)  
   ![Checagem Final no Website](../../imagens/terraform/terraform-github-site.png)

---

## 2. Gerenciando a Chave Secreta (Personal Access Token - PAT)

Um dos gargalos primários neste fluxo e que emperra usuários inexperientes é conectar o Semaphore a um projeto privado do GitHub sem travas recorrentes de negação de acesso (Authentication Failed). O GitHub blindou acessos puros à senhas a um longo tempo atrás. O método correto de integração entre ferramentas sistêmicas exige um *Token*.

Acompanhe as telas que detalhamos validando o passo a passo absoluto, da raiz do GitHub até o seu desfecho, para geração e resgate do seu **Personal access tokens (classic)**:

![Acesso ao Developer Settings](../../imagens/terraform/terraform-github-private-01.png)  
![Encontrando Personal Access Tokens (Classic)](../../imagens/terraform/terraform-github-private-02.png)  
![Engatilhando Criação (Generate New)](../../imagens/terraform/terraform-github-private-03.png)  
![Marcação das Regras e Escopos (Scopes)](../../imagens/terraform/terraform-github-private-04.png)  
![Confirmação do Token](../../imagens/terraform/terraform-github-private-05.png)  
![Console com a String Final Copiável](../../imagens/terraform/terraform-github-private-06.png)

**NÃO COMPROMETA O CÓDIGO CAIXA:** Logo após a última imagem (06) gerar o código da credencial, copie e guarde com resiliência. Depois que você reiniciar ou navegar pela página, o painel impedirá categoricamente de reler ou extrair esta String novamente.

---

## 3. Parametrizando o Semaphore UI

A ponte de integração se encerra transportando o artefato de login modernizado que obtivemos no passo anterior, direto para o cofre seguro do nosso aplicativo Semaphore.

### 3.1 Registrando a Key de API
De volta à interface Web local do painel Semaphore, no menu central, instancie uma nova integração no **Key Store**. Atribua nome correspondente e cadastre explicitamente a sua ferramenta com o tipo Login associado ao seu token "Personal Access" do GitHub:

![Criando a Key no Semaphore](../../imagens/terraform/terraform-semaphore-key-github.png)  
![Atribuindo Login Method](../../imagens/terraform/terraform-semaphore-key-github-02.png)  
![Cadastro Oficial Finalizado](../../imagens/terraform/terraform-semaphore-key-github-03.png)

### 3.2 Amarração do Repositório Mestre (Repository)
Por fim, desça para a subseção de "Repositories". Instanciaremos nossa pasta nas nuvens apontando pela URL padrão (`lab-zero-terraform-teste`) e obrigaremos o sistema a injetar a chave que acabamos de cunhar no "Access Key". Isso furará a bolha comercial de acesso recluso do nosso repositório Private.

![Formulário de Repository Semaphore](../../imagens/terraform/terraform-semaphore-key-github-04.png)  
![Configuração Injetada (Repositório Salvo)](../../imagens/terraform/terraform-semaphore-key-github-05.png)

---

## 📌 Próximos Passos
Tudo atado e pronto! Com as chaves batendo de forma autêntica e seu Código IaC formatado com o padrão GitHub, possuímos o ambiente alinhado e perfeitamente aderente às rotinas mais eficientes do mercado de Deploy DevOps.

A esteira de integração final (Terraform + Semaphore x Proxmox) está devidamente fundamentada no papel e estruturada por chaves. Apenas aguardaremos a criação de nossa nova "Task" oficial do Semaphore para engatilhar as validações definitivas de Infraestrutura como Código!
