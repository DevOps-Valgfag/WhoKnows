# Linting Guide – RuboCop

This document describes how linting is configured and used in this project.
**Linting must pass locally before opening a Pull Request to the `dev` branch.**

The project uses **RuboCop** for Ruby linting to ensure consistent code style,
basic code quality, and early detection of common issues.

The same RuboCop configuration is used locally and in CI.

---

## Scope

This document covers:

- Installing RuboCop locally
- Running RuboCop locally
- Auto-correcting linting issues
- Handling non-auto-fixable offenses
- RuboCop configuration (`.rubocop.yml`)
- CI requirements before Pull Requests

All commands assume you are working inside:

```
new_app_ruby/
```

---

## Prerequisites

- Ruby **3.2**
- Bundler installed
- Dependencies installed via `bundle install`

---

## Installing RuboCop Locally

RuboCop and its extensions must be added to the `Gemfile`
under the `development` and `test` groups:

```ruby
group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-minitest", require: false
end
```

After updating the `Gemfile`, install dependencies:

```bash
bundle install
```

---

## Running RuboCop Locally

To run the linter locally:

```bash
bundle exec rubocop
```

If RuboCop reports:

```
no offenses detected
```

the code is compliant and ready for a Pull Request.

---

## Auto-Correcting Issues

RuboCop can automatically fix **safe** issues such as:

- formatting
- indentation
- spacing
- trailing whitespace
- string literal style

To apply safe auto-corrections:

```bash
bundle exec rubocop -a
```

### Important Notes

- `-a` only applies **safe, non–behavior-changing fixes**
- Aggressive auto-correction (`-A`) is **not used by default**
- Aggressive fixes may change application behavior and must be reviewed carefully

---

## Handling Non-Auto-Fixable Offenses

Some offenses cannot be auto-fixed safely. These typically involve:

- design decisions
- naming conventions
- code structure
- complexity rules
- security-related checks

If:
- the application compiles and runs correctly, and
- remaining offenses are stylistic or design-related,

then rules can be adjusted in the RuboCop configuration file.

---

## RuboCop Configuration (`.rubocop.yml`)

The RuboCop configuration is defined in:

```
new_app_ruby/.rubocop.yml
```

This file is committed to the repository and shared by all team members.
Developers **must not maintain local-only RuboCop configurations**.

The current configuration disables several aggressive or high-risk rules
that would require major refactoring and could affect application behavior.

Even with these rules disabled, RuboCop still checks for:

- syntax errors
- incorrect indentation
- spacing and trailing whitespace
- common Ruby pitfalls
- basic security issues
- general style consistency

---

## Inspecting Enabled RuboCop Rules

To see which rules are currently enforced, you can list active cops by category:

```bash
bundle exec rubocop --show-cops Layout,Lint,Security
```

This helps clarify what RuboCop checks after configuration adjustments.

---

## Continuous Integration (CI) Linting

Linting is enforced automatically using **GitHub Actions**.

### When CI Runs

- On every **Pull Request targeting the `dev` branch**

### What CI Does

1. Checks out the repository
2. Sets up Ruby (based on `.ruby-version`)
3. Installs dependencies via Bundler
4. Runs RuboCop

If RuboCop fails in CI, the Pull Request **cannot be merged**.

---

## Pull Request Checklist (Linting)

Before opening a Pull Request to `dev`:

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Run RuboCop locally:
   ```bash
   bundle exec rubocop
   ```

3. Ensure **no offenses remain**
4. Commit any intentional changes to `.rubocop.yml`
5. Push and open the Pull Request

CI will re-run RuboCop automatically to validate the changes.

---

## Summary

- RuboCop is required locally and in CI
- Safe auto-corrections (`-a`) are encouraged
- Aggressive fixes are avoided by design
- `.rubocop.yml` defines shared linting rules
- CI enforces linting on all PRs to `dev`

This setup ensures consistent code quality while minimizing the risk of
unintended behavior changes.
