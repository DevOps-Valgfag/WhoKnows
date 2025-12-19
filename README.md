# WhoKnows

<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.2+-CC342D?style=for-the-badge&logo=ruby&logoColor=white" alt="Ruby" />
  <img src="https://img.shields.io/badge/Sinatra-4.0-000000?style=for-the-badge&logo=sinatra&logoColor=white" alt="Sinatra" />
  <img src="https://img.shields.io/badge/PostgreSQL-17-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Docker-24+-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/nginx-009639?style=for-the-badge&logo=nginx&logoColor=white" alt="Nginx" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" alt="GitHub Actions" />
  <img src="https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" alt="Prometheus" />
  <img src="https://img.shields.io/badge/RSpec-FF0000?style=for-the-badge&logo=ruby&logoColor=white" alt="RSpec" />
</p>

<p align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/DevOps-Valgfag/app-whoknows/ruby-tests.yml?branch=dev&style=flat-square&label=tests" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square" alt="PRs Welcome" />
</p>

---

A Ruby/Sinatra web application featuring search functionality, user authentication, and weather data. Built with DevOps best practices including containerization, CI/CD, and monitoring.

## Quick Start

```bash
# Clone and navigate
git clone https://github.com/DevOps-Valgfag/app-whoknows.git
cd app-whoknows/new_app_ruby

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run with Docker
docker compose up -d
```

Application available at `http://localhost:80`

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Nginx     │────▶│  Sinatra    │────▶│ PostgreSQL  │
│   :80/:443  │     │    App      │     │    :5432    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ Prometheus  │
                    │  /metrics   │
                    └─────────────┘
```

## Project Structure

```
WhoKnows/
├── .github/
│   └── workflows/          # CI/CD pipelines
├── new_app_ruby/
│   ├── app.rb              # Main application
│   ├── views/              # ERB templates
│   ├── public/             # Static assets
│   ├── spec/               # RSpec tests
│   ├── docker-compose.yml  # Container orchestration
│   ├── Dockerfile          # App container
│   ├── TESTING.md          # Testing guide
│   └── DEPLOYMENT.md       # Deployment guide
├── CONTRIBUTING.md         # Contribution guidelines
└── README.md               # You are here
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Search page |
| `GET` | `/api/search?q=` | Search API |
| `POST` | `/api/login` | User login |
| `POST` | `/api/register` | User registration |
| `GET` | `/api/logout` | User logout |
| `GET` | `/api/weather?city=` | Weather data |
| `GET` | `/metrics` | Prometheus metrics |
| `GET` | `/docs` | Swagger UI |

## Documentation

| Document | Description |
|----------|-------------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Git flow, conventions, PR process |
| [TESTING.md](new_app_ruby/TESTING.md) | How to run tests locally |
| [DEPLOYMENT.md](new_app_ruby/DEPLOYMENT.md) | Docker setup, CI/CD, production |
| [API Docs](http://localhost:8080/docs) | Interactive Swagger documentation |

## Tech Stack

<table>
<tr>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=ruby" width="48" height="48" alt="Ruby" />
<br>Ruby
</td>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=postgres" width="48" height="48" alt="PostgreSQL" />
<br>PostgreSQL
</td>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=docker" width="48" height="48" alt="Docker" />
<br>Docker
</td>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=nginx" width="48" height="48" alt="Nginx" />
<br>Nginx
</td>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=githubactions" width="48" height="48" alt="GitHub Actions" />
<br>CI/CD
</td>
<td align="center" width="96">
<img src="https://skillicons.dev/icons?i=prometheus" width="48" height="48" alt="Prometheus" />
<br>Metrics
</td>
</tr>
</table>

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <sub>Built with Ruby and DevOps best practices</sub>
</p>
