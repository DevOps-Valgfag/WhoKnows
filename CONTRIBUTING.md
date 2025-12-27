# Contributing to WhoKnows

<p align="center">
  <img src="https://img.shields.io/badge/Contributions-Welcome-brightgreen?style=for-the-badge" alt="Contributions Welcome" />
  <img src="https://img.shields.io/badge/Git-Flow-F05032?style=for-the-badge&logo=git&logoColor=white" alt="Git Flow" />
  <img src="https://img.shields.io/badge/Code_Style-RuboCop-CC342D?style=for-the-badge&logo=ruby&logoColor=white" alt="RuboCop" />
</p>

---

Thank you for your interest in contributing to WhoKnows! This document outlines our development workflow and coding conventions.

## Prerequisites

Before contributing, ensure you have:

- Ruby 3.2+
- Bundler
- Docker & Docker Compose
- Git

## Development Setup

```bash
# Clone the repository
git clone https://github.com/DevOps-Valgfag/app-whoknows.git
cd app-whoknows/new_app_ruby

# Install dependencies
bundle install

# Start PostgreSQL for local development
docker run -d --name whoknows-postgres \
  -p 5432:5432 \
  -e POSTGRES_DB=whoknows \
  -e POSTGRES_USER=whoknows \
  -e POSTGRES_PASSWORD=your-secure-password-here \
  postgres:17

# Configure environment
cp .env.example .env
# Edit .env with your database credentials

# Run the application
bundle exec ruby app.rb
```

## Branching Strategy: Git Flow

We use Git Flow with `dev` as the integration branch and `main` for production releases.

```
main ─────────────────────────────────────────▶ (production)
       │                           ▲
       │                           │ (PR: release)
       ▼                           │
dev ──────┬───────┬───────────────────────────▶ (integration)
          │       │       ▲       ▲
          │       │       │       │
          ▼       ▼       │       │
      feature/  feature/  │       │
      auth      search ───┘       │
                                  │
                          bugfix/fix-login ─┘
```

### Workflow Commands

| Step | Command | Description |
|------|---------|-------------|
| 1 | `git checkout dev` | Switch to dev branch |
| 2 | `git pull` | Update local dev |
| 3 | `git checkout -b feature/your-feature` | Create feature branch |
| 4 | `git add .` | Stage changes |
| 5 | `git commit -m "descriptive message"` | Commit with clear message |
| 6 | `git checkout dev` | Switch back to dev |
| 7 | `git pull` | Get latest changes |
| 8 | `git checkout feature/your-feature` | Return to feature branch |
| 9 | `git merge dev` | Merge dev into feature |
| 10 | `git push -u origin feature/your-feature` | Push to remote |

Then create a Pull Request to `dev` in GitHub.

### After PR is Merged

```bash
git checkout dev
git pull
git branch -d feature/your-feature  # Delete local branch
```

## Coding Conventions

Following the [Ruby Style Guide](https://rubystyle.guide/):

| Context | Convention | Example |
|---------|------------|---------|
| Variables, Methods, Symbols | snake_case | `my_variable`, `calculate_total` |
| Classes, Modules | PascalCase | `UserManager`, `SearchHelper` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRIES`, `API_KEY` |
| Files, Directories | snake_case | `user_helper.rb`, `api_controllers/` |
| Database Tables | Plural | `users`, `pages`, `sessions` |
| Numbers in names | No separator | `user1`, `method2` |

### Code Style

```ruby
# Good
def calculate_user_score(user_id)
  user = User.find(user_id)
  user.posts.count * 10
end

# Bad
def calculateUserScore(userId)
  u = User.find(userId)
  return u.posts.count * 10
end
```

## Commit Messages

Write clear, descriptive commit messages:

```
# Good
feat: add user authentication with bcrypt
fix: resolve search pagination bug
docs: update API endpoint documentation
refactor: extract weather service into separate module

# Bad
fixed stuff
update
wip
```

### Commit Prefixes

| Prefix | Use Case |
|--------|----------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `refactor:` | Code refactoring |
| `test:` | Adding tests |
| `chore:` | Maintenance tasks |

## Pull Request Process

1. **Create PR** to `dev` branch (never directly to `main`)
2. **Fill out** the PR template completely
3. **Ensure** all tests pass
4. **Request review** from at least one team member
5. **Address** feedback and update PR
6. **Squash and merge** when approved

### PR Checklist

- [ ] Tests pass locally (`bundle exec rspec`)
- [ ] Code follows conventions
- [ ] PR description explains the changes
- [ ] No sensitive data committed

## Running Tests

Before submitting a PR, ensure all tests pass:

```bash
bundle exec rspec
```

See [TESTING.md](new_app_ruby/TESTING.md) for detailed testing instructions.

## Questions?

If you have questions about contributing, open an issue or reach out to the team.

---

<p align="center">
  <img src="https://img.shields.io/badge/Happy-Coding!-blueviolet?style=flat-square" alt="Happy Coding" />
</p>
