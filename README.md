# Demo Mode

[![Gem Version](https://badge.fury.io/rb/demo_mode.svg)](https://rubygems.org/gems/demo_mode)
[![Tests](https://github.com/Betterment/demo_mode/actions/workflows/tests.yml/badge.svg)](https://github.com/Betterment/demo_mode/actions/workflows/tests.yml)

`DemoMode` is a drop-in "demo" interface for Rails apps, replacing your app's
sign-in form with a very customizable "persona" picker, with a list of
personas that can be defined in just a few lines of code. Each persona
represents a kind of user _template_, allowing you to generate fresh accounts
over and over.

This gem can be used to produce custom deployments of your app, and is ideal
for enabling **💪 highly reliable and repeatable product demos 💪**. It can
also be used to produce sandbox deployments of your app/APIs, and since it also
ships with a developer CLI, it is a super convenient tool for local development
(as a replacement for pre-generated user seeds).

All icons, names, logos, and styles can be customized with your own branding,
but if all you do is define a few personas, you'll get a fully-functioning
interface out of the box (with your app's name in the upper left):

<p align="center"><img width="60%" src="https://user-images.githubusercontent.com/83998/166971945-40588239-c207-44dd-a745-24d4bd368d4b.png" /></p>

We recommend pairing this gem with
[`webvalve`](https://github.com/Betterment/webvalve) (to isolate your app from
any collaborating HTTP services) as well as a "factory" DSL like
[`factory_bot`](https://github.com/thoughtbot/factory_bot) (for generating
accounts concisely). That said, you'll get the most mileage out of whatever
tools you _already use_ in local development & testing, so if you already have
solutions for isolating your app and generating users, use those!

To learn more about how we use `demo_mode` at **Betterment**, check out :sparkles: ["RAILS_ENV=demo" (RailsConf 2022)](https://youtu.be/VibJu9IMohc) :sparkles::

<p align="center"><a href="https://youtu.be/VibJu9IMohc"><img width="50%" src="https://user-images.githubusercontent.com/83998/180073238-b59f42e5-5c3d-4027-9558-e5a6ad6333fe.png" /></a></p>

## Table of Contents

- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [App-Specific Setup](#app-specific-setup)
- [Defining Personas](#defining-personas)
- [Customizing the Design](#customizing-the-design)
- [Optional Features](#optional-features)
  - [The "Sign Up" Link](#the-sign-up-link)
  - [The "Display Credentials" feature](#the-display-credentials-feature)
  - [Developer CLI](#developer-cli)
  - [Callbacks](#callbacks)
  - [Non-User Personas](#non-user-personas)
  - [FactoryBot `sequence` extension](#factorybot-sequence-extension)
  - [Database-backed sequences](#database-backed-sequences)
- [Deploying a demo environment to the cloud](#deploying-a-demo-environment-to-the-cloud)
  - [How to avoid breaking your new "demo" env](#how-to-avoid-breaking-your-new-demo-env)
- [How to Contribute](#how-to-contribute)
  - [Suggested Workflow](#suggested-workflow)

## Getting Started

To get started, add the gem to your `Gemfile` and run `bundle install`:

```ruby
gem 'demo_mode'
```

### Installation

Then, run the installer and the installed migrations:

```
bundle exec rails generate demo_mode:install
bundle exec rails db:migrate
```

The installer will create a config file (at `config/initializers/demo_mode.rb`)
and a sample persona (at `config/personas/sample_persona.rb`). You can ignore
the initializer file for now (it will be covered in the ["Additional
Setup"](#additional-setup) section below).

You should, however, edit the sample persona and fill in the `sign_in_as` block
(don't worry about anything else&mdash;you can read ["Defining
Personas"](#defining-personas) below once you're ready to add more personas):

```ruby
sign_in_as do
  # Define your factory code here! For example:
  # FactoryBot.create(:user)
end
```

Next, "mount" the DemoMode engine at a route of your choice:

```ruby
mount DemoMode::Engine => '/demo' # this will 404 unless Demo Mode is enabled
```

Finally, launch the app in Demo Mode by setting `DEMO_MODE=1` in your
environment:

```
DEMO_MODE=1 bundle exec rails s
```

You should now see your requests rerouted to the following page:

<p align="center"><img width="20%" src="https://user-images.githubusercontent.com/83998/167503249-32d79a19-4bc6-47fa-8633-9b38b8a355ed.png" /></p>

**If not, don't panic!** Your app may need a bit of extra setup in order for
the gem to work as expected, so continue on to the ["App-Specific
Setup"](#app-specific-setup) section.

Otherwise, if everything seems to be working, skip down to ["Defining
Personas"](#defining-personas) to add more personas, or ["Customizing the
Design"](#customizing-the-design) to add your own logo/colors/styles to the UI.
There are also a few ["Optional Features"](#optional-features) to explore. And
if you'd like to deploy a "demo" version of your app somewhere, check out
["Deploying a demo environment to the
cloud"](#deploying-a-demo-environment-to-the-cloud).

### App-Specific Setup

Depending on the conventions of your application, you may need to set a few
extra values in your `config/initializers/demo_mode.rb` file.

#### 1. Tell Demo Mode how to find your "current user"

Demo Mode assumes that your controllers define a conventional `current_user`
method. If your app uses something other than `current_user`, you may tell it
which method to call:

```ruby
DemoMode.configure do
  current_user_method :current_human
end
```

#### 2. Ensure that you have `sign_in` and `sign_out` methods

If your controllers do not already define `sign_in` and/or `sign_out` methods,
define these methods and point them to your true sign-in/sign-out behaviors:

```ruby
# in your `app/controllers/application_controller.rb`:

def sign_in(signinable)
  # log_in!(user: signinable)
end

def sign_out
  # log_out!
end
```

#### 3. Make sure ActiveJob is configured (and running)

In order to use the persona picker UI, your application **must be capable of
running `ActiveJob`-based jobs**. Read [this
guide](https://guides.rubyonrails.org/active_job_basics.html) to get started
with `ActiveJob`.

<img align="left" height="48px" style="padding-right:10px" src="./app/assets/images/demo_mode/loader.png" />

If you're stuck on a loading spinner, you probably need to start a background
job worker, which will depend on your selected backend (e.g. `rake jobs:work`,
etc).

By default, Demo Mode will subclass its job off of `ActiveJob::Base`. If you
want to supply your own base job class, simply uncomment and update this config:

```ruby
DemoMode.configure do
  base_job_name 'MyApplicationJob' # any ActiveJob-compliant class name
end
```

#### 4. Tell Demo Mode which controllers to use

By default, Demo Mode will take over `ApplicationController` (and all of its
descendants), ensuring that any unauthenticated request is re-routed to the
persona picker. This may not be the preferred behavior (if, for example, all
you care about is rerouting the login page), so you can change this default:

```ruby
DemoMode.configure do
  app_base_controller_name 'SignInsController' # or any controller of your choice
end
```

Alternatively, specific controllers can be excluded from this behavior by
adding the following line at the top:

```ruby
skip_before_action :demo_splash!, raise: false
```

Finally, when _rendering the persona picker itself_, Demo Mode will subclass itself
off of `ActionController::Base`. If you'd rather use/define your own base controller
for the demo splash page, you can supply its name:

```ruby
DemoMode.configure do
  splash_base_controller_name 'MyDemoModeBaseController'
end
```

#### 5. Accommodate uniqueness constraints & validations

When generating users on the fly, it is common to run into issues with `UNIQUE`
constraints. (e.g. If each user must have a unique email, your user-generation
code must account for this and generate a unique email each time.) If you are
using [factory_bot](https://github.com/thoughtbot/factory_bot), you will want
to enable our [`sequence` patch](#factorybot-sequence-extension), but be
mindful of the [known issues](#known-issues).

#### Still stuck?

If none of the above gets your "persona picker" into a working state, feel free
to [add an issue](//github.com/Betterment/demo_mode/issues/new) with as many
specifics and screenshots as you can provide.

## Defining Personas

The `demo_mode:install` generator will install an empty persona at
`config/personas/sample_persona.rb`. By default, the file path will dictate the
name of the persona (via `.titleize`), and any persona files you create within
`config/personas/` will automatically appear on the persona picker page (one
persona per file).

Of course, you can always override the name by passing it to the
`generate_persona` method:

```ruby
DemoMode.generate_persona 'My Custom Name' do
  # ...
end
```

Within the `generate_persona` block, you will need to fill in
the `sign_in_as` block with your "factory" code of choice:

```ruby
sign_in_as { FactoryBot.create(:user) }
```

You should also specify a list of features to be displayed
alongside the persona name:

```ruby
features << '1 blog post'
features << '3 comments'
```

Personas up at the top (with user icons) are called "callout" personas and have
`callout true` declared:

```ruby
callout true
```

Personas without `callout true` (or with `callout false`) will show up without
icons, and will appear instead in a searchable/filterable table, making it easy
to support a large number of personas. That said, if your list of personas is
getting _too long_, you can instead define multiple `sign_in_as` blocks as
"variants" of a single persona, which will give them a `select` dropdown in the
UI:

```ruby
variant :pending_invite do
  sign_in_as { FactoryBot.create(:user, :pending_invite) }
end
```

If defined, the non-variant `sign_in_as` will show up as "default" in the
dropdown.

## Customizing the Design

To supply your own branding, you can override the logo
(in the upper left), the loading spinner (shown during persona
generation), and the default persona icon:

```ruby
DemoMode.configure do
  stylesheets.unshift 'first.css'
  stylesheets.push 'last.css'

  logo { image_tag('my-company-logo.svg') }
  loader { render partial: 'shared/loading_spinner' }

  # change the default persona icon to something else:
  icon 'path/to/icon.png'

  # `icon` may alternatively accept a block for arbitrary rendering:
  icon do
    # Any view helpers are available in this context.
    image_tag('images/dancing-penguin.gif')
  end

  # ...
end
```

Individual personas also support the `icon` option, and come with three built-in options:

```ruby
DemoMode.add_persona do
  callout true # icons only apply to "callout" personas

  # Use a symbol for a built-in: `:user` (default), `:users`, and `:tophat`
  icon :tophat

  # Or, again, supply your own icon with a string or block:
  icon 'path/to/my/icon.png'
  icon { image_tag('images/dancing-penguin.gif') }

  # ...
end
```

The styles use these CSS variables, which you can override.

```css
/* Use CSS variables to override the default font and colors: */
:root {
  --font-family: Papyrus, fantasy;
  --primary-color: red;
}
```

You can put anything you want in there! The persona picker UI is constructed
largely with [semantic
markup](https://developer.mozilla.org/en-US/docs/Glossary/Semantics#semantics_in_html=)
and is intended to be easy to customize or style from scratch.

## Optional Features

Your `config/initializers/demo_mode.rb` will be generated with many
commented-out lines. Here are a few optional features you might consider
un-commenting:

### The "Sign Up" Link

To show a "sign up" link in the upper right of the splash page, provide your
`sign_up_path` like so:

```ruby
DemoMode.configure do
  sign_up_path { new_account_path } # or any Rails route
end
```

You'll need to make sure that any sign-up-related controllers are excluded from
the splash page redirect, via a `skip_before_action` or by changing the
`app_base_controller_name` config. See the [controller configuration
instructions](#1-tell-demo-mode-how-to-find-your-current-user) above for
detailed instructions!

### The "Display Credentials" feature

You may optionally display the account's credentials as an extra step, prior to
signing in. This comes with the option to "sign in manually" (via your app's
login form), and can be useful for stepping through login features like
multi-factor authentication (which would otherwise be skipped by the persona
picker):

```ruby
DemoMode.configure do
  display_credentials
  sign_in_path { login_path } # tell Demo Mode where your login path is
end
```

You may also toggle this feature on or off on a per-persona basis:

```ruby
DemoMode.add_persona do
  display_credentials false
end
```

By default, Demo Mode will generate a new password for you. Make sure that you
actually make use of `DemoMode.current_password` when constructing your user:

```ruby
DemoMode.add_persona do
  sign_in_as do
    User.create(..., password: DemoMode.current_password)
  end
end
```

You may also define your own "password generator":

```ruby
DemoMode.configure do
  # very random password:
  password { SecureRandom.uuid }

  # or always the same password:
  password { "RailsConf2022" }
end
```

### Developer CLI

Demo Mode ships with a developer-friendly CLI! Simply run the following, and
follow the interactive prompt to generate an account:

```bash
bundle exec rake persona:create
```

This will generate the account and output the sign-in credentials:

```
┏━━ ⭑ Basic User ⭑ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
┃ 👤 :: user-3@example.org
┃ 🔑 :: aReallyCoolPassword
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (0.0s) ━
```

Much like the ["Display Credentials"](#display-credentials) feature above,
you'll need to make use of `DemoMode.current_password` in your personas (and/or
customize the default password generator) in order for these credentials to be
valid!

You can customize the rake task's name within your app's `Rakefile`:

```ruby
task create_user: 'persona:create'
```

### Callbacks

You may choose to wrap persona generation with some additional logic. Say,
for example, you want to set some extra global state, or run some code that
modifies every persona you generate:

```ruby
DemoMode.configure do
  around_persona_generation do |generator, options|
    generator.call(options).tap do |account|
      account.update!(metadata: '123')
    end
  end
end
```

You must run `generator.call` and return the "signinable" object from
the callback block.

### Non-User Personas

Sometimes the thing you want to demo isn't something a logged-in user would
see, but also isn't something accessible to any visitor. For example, maybe
your app supports private invite tokens, and you'd like to have a persona that
generates a token and links to this exclusive "sign up" behavior.

To do this, you can define a persona that returns some other object in its
`sign_in_as` block. For example, let's return an invite token:

```ruby
sign_in_as do
  FactoryBot.create(:invite_token)
end
```

Then, you can define a custom `begin_demo` behavior. This will replace the
usual `sign_in(...)` call with anything of your choice, and the model we
generated above is accessible as `@session.signinable`:

```ruby
begin_demo do
  redirect_to sign_up_path(invite: @session.signinable.invite_token)
end
```

### FactoryBot extensions

Factory bot ships two patches that may be manually loaded after loading FactoryBot:

```ruby
require 'factory_bot'
require 'demo_mode/factory_bot_ext'
```

#### `sequence`

`DemoMode` comes with a patch designed to be a drop-in replacement for
[factory_bot](https://github.com/thoughtbot/factory_bot)'s `sequence` feature,
ensuring that sequences like this...

```ruby
sequence(:column_name) { |i| "Something #{i}" }
```

...will continue working across Ruby processes even after there are existing
records in the DB (rather than starting at "Something 1" each time). This
feature is necessary wherever you rely on `UNIQUE` constraints in the database,
or uniqueness validations on your models.

#### `around_each` hook

Use `FactoryBot.around_each` to wrap all factory execution, which can be used to
skip expensive callbacks/logging:

```ruby
FactoryBot.around_each do |&blk|
  was_enabled = MyLogger.enabled?
  MyLogger.disable!
  blk.call
ensure
  MyLogger.enable! if was_enabled
end
```

#### Considerations

- The sequences extension is **not concurrency-safe**, so if you
  run multiple server threads/processes, you will want to take
  out a mutex prior to generating each persona:

  ```ruby
  DemoMode.configure do
    # ...
    around_persona_generation do |generator|
      # Here we rely on https://github.com/ClosureTree/with_advisory_lock
      ActiveRecord::Base.with_advisory_lock('demo_mode') do
        generator.call
      end
    end
  end
  ```

- The sequences extension **does not play well with deletions**,
  since it may encounter these gaps and assume it has reached
  the next starting value. If your application must support
  deletions on models with sequences, the recommended workaround
  is to remove the impacted `UNIQUE` constraints (**only in your
  deployed demo/sandbox instances**, of course) and
  conditionally disable any uniqueness validations (e.g.
  `validates ... unless DemoMode.enabled?`).

### Database-backed sequences

By default, `CleverSequence` (used by the FactoryBot `sequence` extension) uses an in-memory Ruby counter. For production demo environments running multiple processes or requiring persistence across restarts, you can enable PostgreSQL-backed sequences:

```ruby
DemoMode.configure do
  CleverSequence.use_database_sequences = true
end
```

This feature flag controls whether `CleverSequence` uses PostgreSQL native sequences or the existing Ruby-based counter, allowing for gradual rollout and easy rollback. By default, `use_database_sequences` is `false`.

You can check the current setting with:

```ruby
CleverSequence.use_database_sequences? # => false (default)
```

You can also enforce that database sequences exist before they are used. When enabled, `CleverSequence` will raise an error if a sequence is requested but the corresponding PostgreSQL SEQUENCE does not exist yet (prompting the engineer to run a migration that creates the SEQUENCE). When disabled (the default), `CleverSequence` will fall back to calculating the next sequence value based on existing database data:

```ruby
DemoMode.configure do
  CleverSequence.enforce_sequences_exist = true
end
```

You can check this setting with:

```ruby
CleverSequence.enforce_sequences_exist? # => false (default)
```

**Note:** These features require PostgreSQL and will be implemented in a future release.

## Deploying a demo environment to the cloud

This gem truly shines when used to deploy a "demo" version of
your app to the cloud!

While the details of a custom environment deployment will vary
from app to app, you can get started by simply adding a
`demo.rb` file to your `config/environments` folder:

```ruby
Rails.application.configure do
  ENV['DEMO_MODE'] = true

  # Recommended production-like behaviors:
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.assets.compile = false
  config.assets.unknown_asset_fallback = false
  config.assets.digest = true
  config.force_ssl = true
  config.action_dispatch.show_exceptions = false

  # Recommended development/test-like behaviors:
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_deliveries = false
end
```

We recommend using production-like caching/precompiling, but be
sure to use test/development-like configurations for emails and
any external HTTP requests / API connections! If you currently
have no way of stubbing out these behaviors, **we strongly
encourage configuring your app to use
[`webvalve`](https://github.com/Betterment/webvalve)** before
you attempt to set up a demo environment.

With the above environment configured, you can now launch your app in this mode:

```ruby
RAILS_ENV=demo bundle exec rails s
```

(Remember that you can always launch your app with `DEMO_MODE=true`, regardless
of the Rails environment, so don't worry about `RAILS_ENV` until it's time to
deploy something somewhere.)

### How to avoid breaking your new "demo" env

#### Step 1: Tests!

It's strongly suggested that you build end-to-end integration/feature tests
into your application's test suite. You can toggle `ENV['DEMO_MODE']` on and
off directly from within tests, or, if you use RSpec, you can enable Demo Mode
with the following `before` block:

```ruby
before do
  allow(DemoMode).to receive(:enabled?).and_return(true)
end
```

Then, write a test that actually exercises the persona sign-in flow and steps
through your app experience as that persona:

```ruby
scenario 'an important product demo' do
  persona_picker.main_user.sign_in.click
  expect(demo_loading_page).to be_loaded
  work_off_jobs!

  expect(dashboard_page).to be_loaded
  expect(dashboard_page).to have_blog_posts(count: 1)
  # etc ...
end
```

This ensures that your demo personas are tested as part of your
tests locally and in CI, and if your tests step carefully
through the pages that are typically demoed, you can be more
confident that changes to your app won't lead to surprise
breakages in your demo-enabled environments.

You may also wish to add a "unit" tests to ensure that each
persona can be generated on its own and doesn't rely on
hardcoded values for uniqueness:

```ruby
DemoMode.personas.each do |persona|
  persona.variants.keys.each do |variant|
    RSpec.describe("Persona: '#{persona.name}', '#{variant}'") do
      it 'can be generated twice in a row' do
        persona.generate!(variant: variant)
        persona.generate!(variant: variant)
      end
    end
  end
end
```

#### Step 2: Monitoring!

Finally, once you've deployed your demo environment, we
encourage you to monitor it the same way you would your
production instance. (This is especially important if you use
this environment to deliver live product demos to other humans!)

Exceptions should be configured to go to your error tracker,
alerts should still be wired up to ping your engineers, and if
you operate an "on call" process, engineers should be made aware
that this demo environment _is_ a "production-like" environment
and should expect "production-like" uptime guarantees.

We also emit an `ActiveSupport::Notifications` event
(`demo_mode.persona_generated`) every time a persona is generated, which can be
useful for tracking usage over time and alerting to any unexpected spikes or
drops in usage. The event payload includes the persona name, variant, execution
duration, and exception details (if an error occurred during generation).

Again, to learn more about how we use and operate our "demo"
environments at **Betterment**, check out our ✨ [RailsConf 2022 talk entitled
"RAILS_ENV=demo"](https://youtu.be/VibJu9IMohc)
✨!

## How to Contribute

We would love for you to contribute! Anything that benefits the majority
of `demo_mode` users—from a documentation fix to an entirely new
feature—is encouraged.

Before diving in, [check our issue
tracker](//github.com/Betterment/demo_mode/issues) and consider
creating a new issue to get early feedback on your proposed change.

### Suggested Workflow

- Fork the project and create a new branch for your contribution.
- Write your contribution (and any applicable test coverage).
- Make sure all tests pass (`bundle exec rake`).
- Submit a pull request.
