# WhoKnows Application 🚀

![Ruby](https://img.shields.io/badge/Ruby-3.0%2B-red?logo=ruby&logoColor=white)
![Sinatra](https://img.shields.io/badge/Sinatra-2.1%2B-lightgrey?logo=sinatra)
![SQLite](https://img.shields.io/badge/SQLite3-Required-blue?logo=sqlite)
![License](https://img.shields.io/badge/License-MIT-green)

## Project Overview

WhoKnows is a Ruby/Sinatra-based web application that provides various features, including user authentication, search functionality, and weather data retrieval. The application is designed to be lightweight, easy to set up, and extensible.

<p align="center">
  <img src="https://img.shields.io/badge/ruby-%23CC342D.svg?style=for-the-badge&logo=ruby&logoColor=white" alt="Ruby" />
  <img src="https://img.shields.io/badge/sinatra-%23000.svg?style=for-the-badge&logo=sinatra&logoColor=white" alt="Sinatra" />
  <img src="https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/YAML-grey?style=for-the-badge&logo=yaml&logoColor=white" alt="YAML" />
  <img src="https://img.shields.io/badge/json-5E5C5C?style=for-the-badge&logo=json&logoColor=white" alt="JSON" />
  <img src="https://img.shields.io/badge/dotenv-ECD53F?style=for-the-badge&logo=dotenv&logoColor=black" alt="Dotenv" />
  <img src="https://img.shields.io/badge/BCrypt-627E99?style=for-the-badge&logo=lock&logoColor=white" alt="BCrypt" />
</p>

---

## 📂 Folder Structure

A brief overview of the key directories and files in the project.

```
├── new_app_ruby/       # Main application folder
│   ├── app.rb          # Main Sinatra application file
│   ├── views/          # HTML templates for rendering
│   ├── public/         # Static assets (CSS, JS, images)
│   ├── db/             # Database-related files
│   └── .env            # Environment variables
├── README.md           # Project documentation
└── open_api.yaml       # OpenAPI specification
```

---

## 🛠️ Setting Up the Project Locally

To get the project up and running on your local machine, please follow these steps.

### Prerequisites ✅

Before you begin, ensure you have the following software installed on your system.

1.  **Ruby:** This project requires Ruby. Version 3.0 or higher is recommended. To check your Ruby version, run the following command in your terminal:
    ```sh
    ruby -v
    ```
    If you don't have Ruby installed, you can download it from the official [Ruby website](https://www.ruby-lang.org/).

2.  **Bundler:** Bundler is a package manager for Ruby. To install it, run:
    ```sh
    gem install bundler
    ```

3.  **SQLite3:** This project uses SQLite3 as its database. You can verify if it's installed by running:
    ```sh
    sqlite3 --version
    ```
    If it's not installed, you can find installation instructions on the [SQLite website](https://www.sqlite.org/).
### 🚀 Setup Instructions

1.  **Clone the Repository:**
    First, clone the project repository to your local machine.
    ```sh
    git clone <your-repository-url>
    cd <project-directory>
    ```

2.  **Install Dependencies:**
    Next, install the necessary Ruby gems. To keep the gems local to the project and avoid conflicts with system-wide gems, it is recommended to configure Bundler to install dependencies into the `vendor/bundle` directory.

    Run this command first:
    ```sh
    bundle config set --local path 'vendor/bundle'
    ```
    Now, install the gems:
    ```sh
    bundle install
    ```

3.  **Download the Database:**
    This project uses a pre-existing database file. You will need to download the official `whoknows.db` file from the provided external source and place it in the root directory of the project.

4.  **Configure Environment Variables:**
    The application requires a `SESSION_SECRET` for security. Create a `.env` file in the new_app_ruby folder:
    ```sh
    touch .env
    ```
    Then, add the following line to the `.env` file:
    ```env
    SESSION_SECRET=your_super_secret_key
    ```
    You can generate a secure secret key by running the following command in your terminal and copying the output:
    ```sh
    ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
    ```

### Running the Application

Once you have completed the setup steps, you can start the application with the following command:

```sh
bundle exec ruby app.rb
```

The application will then be accessible at `http://localhost:8080`.

### Troubleshooting

If you encounter any issues during the setup process, here are a few things to check:

*   **Missing Gems:** If you get an error about a missing gem, double-check that you have run `bundle install` successfully.
*   **Database Not Found:** Ensure that you have downloaded the `whoknows.db` file and placed it in the correct directory.
*   **Application Fails to Start:** Verify that your `.env` file is correctly named and that the `SESSION_SECRET` is set.

---
## API Endpoints

Below is a quick overview of the available API endpoints in the application. For detailed specifications, refer to the [OpenAPI documentation](http://localhost:8080/docs).

### General Endpoints

| Method | Endpoint         | Description                          |
|--------|-------------------|--------------------------------------|
| GET    | `/`              | Root endpoint. Displays a welcome message. |
| GET    | `/docs`          | Swagger UI for OpenAPI documentation. |
| GET    | `/about`         | Displays the "About" page.           |

---

### Authentication Endpoints 🔒

| Method | Endpoint         | Description                          |
|--------|-------------------|--------------------------------------|
| POST   | `/api/login`     | Logs in a user with username and password. |
| POST   | `/api/register`  | Registers a new user.                |
| GET    | `/api/logout`    | Logs out the current user.           |

---

### Search Endpoint 🔍

| Method | Endpoint         | Description                          |
|--------|-------------------|--------------------------------------|
| GET    | `/api/search`    | Searches for pages based on a query and language. |

---

### Weather Endpoints 🌦️

| Method | Endpoint         | Description                          |
|--------|-------------------|--------------------------------------|
| GET    | `/api/weather`   | Returns weather data for a specified city in JSON format. |
| GET    | `/weather`       | Displays an HTML weather forecast for a specified city. |

---

### OpenAPI Specification Endpoints 📜

| Method | Endpoint         | Description                          |
|--------|-------------------|--------------------------------------|
| GET    | `/open_api.yaml` | Returns the OpenAPI specification in YAML format. |
| GET    | `/open_api.json` | Returns the OpenAPI specification in JSON format. |

---

### Notes
- **Authentication**: Some endpoints may require the user to be logged in. Ensure you have a valid session.
- **Environment Variables**: The application uses a `SESSION_SECRET` for session management. Ensure this is configured in your `.env` file.
- **Database**: The application relies on an external SQLite database file. Ensure the database is downloaded and placed in the correct directory.

For more details, visit the [Swagger UI](http://localhost:8080/docs).

🐛 Known Issues

-   The `/api/weather` endpoint is dependent on an external weather service and may fail if the service is unavailable.
-   The database file must be manually downloaded and placed in the correct directory.



## Agreed conventions new version of the application - Ruby / Sinatra
According to https://rubystyle.guide/ 

| Concept/Context | Convention  | Example |
|-----------------|-------------|---------|
| Ruby Variables, Symbols and Methods | Snake case | `my_variable`, `some_method` |
| Do not separate numbers from letters on symbols, methods and variables. | Snake case | `my_variable1`, `some_method2` |
| Ruby Classes and Modules | Pascal case | `MyClass`, `UserManager` |
| Files and Directories | Snake case | `hello_world.rb`, `/hello_world/hello_world.rb` |
| Database Tables/Collections | Plural | `customers`, `orders` |


---
## Agreed branching strategy - Git Flow
We will work in feature branches, make PR to Dev branch and when the application is ready for deployment, this will be from the Main branch.

Flow and commands in order to avoid irreparable conflicts:
| Command | Desc.  | 
|-----------------|-------------|
| git checkout featureBranch |  |
| git add . | |
| git commit -m "descriptive message" | |
| git fetch origin | gets all changes from remote, but do not change the local code |
| git rebase origin/dev | moves/adds local commits to the latest version of dev from remote* |
| git push -u origin featureBranch | pusher din rebased branch til remote, klar til PR |

*If there are any conflicts during rebase, solve these in the IDE (the save files, run git add <file> + git rebase --continue)

Make PR to dev in GitHub UI.


After PR has been reviewed and merged:

git checkout dev

git pull 

Now you can make a new feature branch from the updated dev branch and work on.
