# Modelo IAC

Repositório público de apoio à pesquisa científica sobre Infraestrutura como Código (IaC), com foco em Proxmox, Docker, Terraform e Ansible.

## Objetivo

Este projeto organiza a documentação, os tutoriais e os arquivos de automação usados para reproduzir um laboratório de infraestrutura virtualizada. O material foi pensado para ser reutilizável, auditável e fácil de citar em contexto acadêmico.

O objetivo central é demonstrar como é possível provisionar, configurar e gerenciar laboratórios completos de contêineres LXC no Proxmox de forma automatizada, reprodutível e segura — substituindo processos manuais e repetitivos por código versionado.

## Estrutura

```text
/
├─ README.md
├─ CITATION.cff
├─ LICENSE
├─ .gitignore
├─ docs/
│  ├─ index.md
│  ├─ arquitetura/
│  └─ tutoriais/
├─ imagens/
│  ├─ capturas/
│  └─ diagramas/
├─ terraform/
│  ├─ main.tf
│  ├─ providers.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  ├─ environments/
│  └─ modules/
└─ ansible/
	├─ ansible.cfg
	├─ inventories/
	├─ playbooks/
	└─ roles/
```

## Organização recomendada

- Use `docs/` para explicações conceituais, arquitetura e passo a passo.
- Use `imagens/` para capturas de tela, diagramas e evidências da pesquisa.
- Use `terraform/` para a automação de infraestrutura.
- Use `ansible/` para provisionamento e configuração dos sistemas.

## Como usar

1. Leia [docs/index.md](docs/index.md) para entender a navegação do repositório.
2. Consulte os tutoriais em [docs/tutoriais/README.md](docs/tutoriais/README.md).
3. Adapte os arquivos de [terraform/](terraform) e [ansible/](ansible) para o seu laboratório.
4. Armazene imagens e capturas em [imagens/](imagens).

## Observações para publicação

- Evite subir segredos, IPs privados sensíveis e credenciais reais.
- Prefira exemplos anonimizados ou intervalos reservados para documentação.
- Registre a forma de citação no arquivo [CITATION.cff](CITATION.cff).

## Licença

Defina a licença mais adequada antes da divulgação final. Para materiais acadêmicos, é comum separar a licença do código da licença da documentação.
