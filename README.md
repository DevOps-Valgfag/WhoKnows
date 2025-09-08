# WhoKnows has New owners Now WeKnows is the new!

## Dependency Graph:
First edition, headlines only
### https://is.gd/VIYoWi

---

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
