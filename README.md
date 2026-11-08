# Bancos gerenciados dos microsserviços

Este repositório provisiona RDS PostgreSQL e os segredos/certificados do MongoDB em us-east-1, e automatiza usuários/grants e verificações pelo EKS. O MongoDB é um StatefulSet mantido pelo Infra no estágio messaging.

- RDS PostgreSQL 18.3, db.t4g.micro, 20 GiB gp3, Single-AZ: fiap_os e fiap_billing, com usuários exclusivos.
- MongoDB 8.0: replica set rs0 de um membro no EKS, TLS obrigatório, EBS gp3 criptografado de 20 GiB; fiap_execution com usuário readWrite exclusivo. Não há alta disponibilidade ou backup permanente neste laboratório.
- Secrets Manager: fiap-{os,billing,execution}-database-credentials, fiap-postgres-admin e fiap-mongodb-admin. Senhas/keyfile e certificados são gerados pelo Terraform; não configurar db_username/db_password no GitHub. Somente o namespace MongoDB e os Jobs administrativos recebem o segredo administrativo.
- RDS aceita somente os nós EKS; MongoDB tem Service interno e NetworkPolicy para Execution/Jobs. O runner GitHub não conecta diretamente aos bancos.

A chave do state continua terraform/database/terraform.tfstate. A transição exige esvaziar o estado legado com seu código antigo antes de aplicar esta topologia; não há migração de dados.

## Entrega

### Substituição do DocumentDB

A conta recusou DocumentDB com `FreeTierRestrictionError`; o usuário escolheu MongoDB no EKS. Não há criação de DocumentDB nem exigência de upgrade por esse componente. A cobrança/elegibilidade dos demais recursos continua sujeita ao plano e aos créditos da conta.

Publicar Infra, DB e Execution de forma coordenada, e reaplicar o bootstrap administrativo para permitir à role Database gerenciar `fiap-mongodb-admin`. Depois publicar o principal e iniciar um novo `apply` central. O estágio database cria credenciais/CA antes de kubernetes-configs; messaging cria MongoDB/Kafka; initialize-databases aguarda os segredos e inicializa o usuário da API. Preservar o state: recursos DocumentDB e o segredo antigo eventualmente existentes serão removidos pelo plano. O inventário e as permissões do segredo antigo permanecem para essa limpeza; não há migração de dados.

O segredo MongoDB usa o DNS estável `mongodb-0.mongodb.fiap-mongodb.svc.cluster.local`, replicaSet=rs0, TLS, retryWrites=true e pool máximo de 10. O servidor autentica membros por keyfile e clientes por usuário/senha. A CA pública é distribuída separadamente; chaves privadas ficam no Secrets Manager/state. O certificado do servidor vale um ano; após renovação/rotação do segredo, reiniciar o StatefulSet para copiar os arquivos novos. Não rotacionar a senha administrativa somente no Secrets Manager sem alterar também o usuário no banco existente.

Os workflows terraform-stage.yml e initialize-databases.yml são chamados exclusivamente pelo orquestrador manage-platform.yml do repositório principal. O primeiro recebe stage, operation, source_sha e role_arn. O segundo recebe source_sha, role_arn e execution_image por digest. OIDC usa o principal em main; REPOSITORIES_TOKEN é necessário para fontes privadas.

Inicialização cria/atualiza usuários e grants idempotentemente. Testa acesso ao próprio PostgreSQL e rejeição cruzada. O Job de compatibilidade executa --verify-persistence da imagem Execution em banco temporário, com TLS/CA, índice único parcial, commit, abort, conflito de escrita e deduplicação. Se falhar, a entrega para antes do rollout. As migrations EF pertencem a OS/Billing e são executadas pelos respectivos Jobs de entrega.

As chaves lógicas dos outputs Terraform continuam `postgres_admin`/`mongodb_admin`. No Kubernetes, os ExternalSecrets e Secrets se chamam `database-postgres-admin`/`database-mongodb-admin`: nomes DNS não aceitam underscore. `bootstrap-secrets.mjs` aplica essa normalização às referências dos Jobs e à espera de sincronização. O workflow de inicialização executa os testes de nomes antes de autenticar na AWS.

## Destruição e validação

RDS usa backup_retention_period=0 e skip_final_snapshot=true. MongoDB usa PVC com retenção Delete ao excluir o StatefulSet, e o estágio messaging aguarda a exclusão do EBS antes de retirar o driver. Destroy apaga os dados. O estado remoto versionado, incluindo credenciais antigas e chaves privadas, permanece sensível no bootstrap preservado.

O Manage AWS central executa `destroy_database` depois de messaging/configurações e antes de add-ons/core. Configurações consome os outputs database e deve ser removido antes de esvaziá-los. Excluir o RDS remove os bancos `fiap_os` e `fiap_billing`; excluir o volume MongoDB remove `fiap_execution`. Ao fim do estágio database (também se o state estiver vazio), `verify-databases-deleted.mjs` exige ausência de instâncias/clusters RDS/DocumentDB `fiap-*` e EBS com tags `Project=fiap-tech-challenge`, `Component=mongodb`/`kafka`. Qualquer remanescente ou falha de inventário bloqueia a sequência. Não apaga recursos encontrados fora do state por varredura; é necessário corrigir a gestão dos recursos e retomar o destroy.

O CI executa `node --test scripts/platform/*.test.mjs`, incluindo os casos de bancos/volumes remanescentes e erro de permissão. Os testes usam inventário simulado; não excluem bancos AWS. Publicar DB e Infra antes do principal para ativar a sequência atualizada.

Verificar terraform fmt -check, init -backend=false e validate com TF_DATA_DIR isolado. A validação real acontece após publicação/bootstrap, pelo ciclo central. Consulte o [guia operacional](https://github.com/Maieru/fiap-tech-challenge/blob/main/docs/operacao/plataforma-aws.md).
