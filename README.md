# Bancos gerenciados dos microsserviços

Este repositório provisiona RDS PostgreSQL e DocumentDB privados/criptografados em us-east-1, e automatiza usuários/grants e compatibilidade pelo EKS.

- RDS PostgreSQL 18.3, db.t4g.micro, 20 GiB gp3, Single-AZ: fiap_os e fiap_billing, com usuários exclusivos.
- DocumentDB 5.0, db.t4g.medium: fiap_execution; autenticação em admin e readWrite restrito ao banco.
- Secrets Manager: fiap-{os,billing,execution}-database-credentials, fiap-postgres-admin e fiap-documentdb-admin. Senhas são aleatórias; não configurar db_username/db_password no GitHub.
- Portas de banco aceitam somente os nós EKS. Jobs executam na VPC; o runner GitHub não conecta diretamente aos bancos.

A chave do state continua terraform/database/terraform.tfstate. A transição exige esvaziar o estado legado com seu código antigo antes de aplicar esta topologia; não há migração de dados.

## Entrega

Os workflows terraform-stage.yml e initialize-databases.yml são chamados exclusivamente pelo orquestrador manage-platform.yml do repositório principal. O primeiro recebe stage, operation, source_sha e role_arn. O segundo recebe source_sha, role_arn e execution_image por digest. OIDC usa o principal em main; REPOSITORIES_TOKEN é necessário para fontes privadas.

Inicialização cria/atualiza usuários e grants idempotentemente. Testa acesso ao próprio PostgreSQL e rejeição cruzada. O Job de compatibilidade executa --verify-persistence da imagem Execution em banco temporário, com TLS/CA, índice único parcial, commit, abort, conflito de escrita e deduplicação. Se falhar, a entrega para antes do rollout. As migrations EF pertencem a OS/Billing e são executadas pelos respectivos Jobs de entrega.

## Destruição e validação

RDS usa backup_retention_period=0 e ambos os bancos usam skip_final_snapshot=true. DocumentDB retém backups automaticamente pelo mínimo de um dia enquanto ativo. Destroy apaga os dados. O estado remoto versionado, incluindo credenciais antigas, permanece sensível no bootstrap preservado.

Verificar terraform fmt -check, init -backend=false e validate com TF_DATA_DIR isolado. A validação real acontece após publicação/bootstrap, pelo ciclo central. Consulte o [guia operacional](https://github.com/Maieru/fiap-tech-challenge/blob/main/docs/operacao/plataforma-aws.md).
