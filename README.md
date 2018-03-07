# `check_for_extra_migrations`

Have you ever realized that your database schema reflected migrations you'd run in another branch of your Rails project, which you'd forgotten to roll back?

This gem fixes that. You set it up to run as a Git `post-checkout` hook, and it alerts you when you `git checkout` a branch that's missing migrations you've run in another branch.

For example:

```
~ (master) $ git checkout -b create-users
~ (create-users) $ rails generate model User email:string
~ (create-users) $ rake db:migrate
~ (create-users) $ git add --all; git commit -m "Create Users"
~ (create-users) $ git checkout master
Migrations have been run that are not present in this branch ('master'): 20180113151238.
* The migration 20180113151238 first appeared in commit a2d27b6db1e82f71c8ce7fd40ba0cb133c11785d, which is on these branches: 'create-users'.
~ (master) $
```


## Installation

### 1. Install gem

```
git clone https://github.com/kevinlitchfield/check_for_extra_migrations.git
cd check_for_extra_migrations
gem build check_for_extra_migrations.gemspec
gem install check_for_extra_migrations-0.0.2.gem
```


### 2. Create hook

In `.git/hooks/post-receive` in your Rails project:

```sh
#!/bin/sh
check_for_extra_migrations
```

Run `chmod +x` on `.git/hooks/post-receive`.


### 3. Calibrate (if necessary)

If you have deleted migration files in the past that were run and not rolled back, your database's understanding of what migrations you've run (as reflected in the `schema_migrations` table) will be out of sync with what's reflected in your codebase.

Run `check_for_extra_migrations calibrate` to save the ids of those migrations to an `.extra_migrations` file in the root of your Rails project. They will be ignored in the future.


## Limitations

Only works for Postgres.
