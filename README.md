![banner](docs/img/banner.png)
# Ro-DOU

[![CI Tests](https://github.com/gestaogovbr/Ro-dou/actions/workflows/ci-tests.yml/badge.svg)](https://github.com/gestaogovbr/Ro-dou/actions/workflows/ci-tests.yml) 
![Python](https://img.shields.io/badge/Python-%3E%3D3.8-blue) ![Docker](https://img.shields.io/badge/Docker-%232496ED?logo=docker) ![Airflow](https://img.shields.io/badge/Apache%20Airflow-2.x-orange?logo=apache-airflow) ![Postgres](https://img.shields.io/badge/PostgreSQL-13-blue?logo=postgresql) ![Pydantic](https://img.shields.io/badge/Pydantic-1.x-brightgreen) ![PyYAML](https://img.shields.io/badge/PyYAML-present-blue)

O Ro-DOU é uma ferramenta que faz clipping do Diário Oficial da União (D.O.U.) e de diários municipais via Querido Diário. Ele processa publicações, gera relatórios e envia notificações (e-mail, Slack, Discord ou outros) quando encontra correspondências para os termos configurados.

Documentação completa e exemplos estão em: https://gestaogovbr.github.io/Ro-dou/

## Ferramentas e bibliotecas principais
- Python (runtime do projeto)
- Apache Airflow (orquestração de DAGs)
- Docker / Docker Compose (ambientes e containers)
- PostgreSQL (armazenamento)
- Pydantic (validação de configurações YAML)
- PyYAML (parsing de YAML)
- psycopg2 (conector PostgreSQL)
- requests / httpx (chamadas HTTP)
- pytest (testes automatizados)

## Fork ANPD — especializações desta cópia
Esta cópia é mantida pela ANPD com adaptações operacionais para ambientes internos. Principais mudanças na branch `feat/make-bootstrap` (vs `origin/main:HEAD`):
- Evita retries desnecessários em falhas por `SSLError` em chamadas de rede.
- Parametriza o `Makefile` para builds e execuções mais flexíveis em CI/local.
- Aumenta a robustez do `Dockerfile` durante o build.
- Ajustes de bootstrap do Airflow: migrações automáticas e criação de usuário admin para facilitar desenvolvimento local.
- Ajustes no `docker-compose.yml` para dev (omissão intencional do `version:`, fallbacks seguros e `smtp4dev` em `profiles: ["dev"]`).

> Consulte `CHANGELOG.md` para o histórico completo de releases.

### Diferenças em relação ao upstream
- Mantemos apenas DAGs e configurações voltadas à ANPD; os exemplos genéricos em `dag_confs/examples_and_tests/` seguem de fora para simplificar manutenção.
- Artefatos de deploy em Kubernetes (`k8s/`) e pipelines de publicação Docker/GitHub Pages não fazem parte deste fork, já que o fluxo oficial roda em ambientes controlados próprios.
- A suíte de testes automatizados do upstream não é executada aqui; os ajustes passam por verificação manual em ambiente de desenvolvimento dedicado.
- Dependências opcionais que causavam falhas (por exemplo, providers MSSQL ausentes) permanecem protegidas — recursos só são habilitados quando necessários ao nosso fluxo.

## Links úteis
- Documentação do projeto: https://gestaogovbr.github.io/Ro-dou/
- Changelog: `CHANGELOG.md`
- Canal da comunidade: https://discord.gg/8R6bS5D2KN

---

Posso commitar e dar push desta versão consolidada do `README.md` (usa uma mensagem padrão `docs: consolidar README e adicionar badges`) ou aplicar outra mensagem — diga qual prefere.
