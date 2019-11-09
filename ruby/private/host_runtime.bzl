load(":bundler.bzl", "install_bundler")
load("//ruby/private:constants.bzl", "RULES_RUBY_WORKSPACE_NAME")
load("//ruby/private/tools:repository_context.bzl", "ruby_repository_context")

def _is_subpath(path, ancestors):
  """Determines if path is a subdirectory of one of the ancestors"""
  for ancestor in ancestors:
    if not ancestor.endswith('/'):
      ancestor += '/'
    if path.startswith(ancestor):
      return True
  return False

def _relativate(path):
    if not path:
      return path
    # Assuming that absolute paths start with "/".
    # TODO(yugui) support windows
    if path.startswith('/'):
      return path[1:]
    else:
      return path

def _list_libdirs(ruby):
  """List the LOAD_PATH of the ruby"""
  paths = ruby.eval(ruby, 'print $:.join("\\n")')
  paths = sorted(paths.split("\n"))
  rel_paths = [_relativate(path) for path in paths]
  return (paths, rel_paths)

def _install_dirs(ctx, ruby, *names):
  paths = sorted([ruby.rbconfig(ruby, name) for name in names])
  rel_paths = [_relativate(path) for path in paths]
  for i, (path, rel_path) in enumerate(zip(paths, rel_paths)):
    if not _is_subpath(path, paths[:i]):
      ctx.symlink(path, rel_path)
  return rel_paths

def _bin_install_path(ruby, bin):
  """Transform the given command name "bin" to actual file name.

  Uses the same logic as "script_installer" in tools/rbinstall.rb in Ruby.
  But it does not currently support RbConfig::CONFIG['program_transform_name']
  """
  install_name = ruby.expand_rbconfig(ruby, '${bindir}/${ruby_install_name}')
  return install_name.replace('ruby', bin, 1)


def _locate_script(ctx, ruby, gem_name, bin_name):
  return ruby.run_ruby(
      ruby,
      ctx.path(ctx.attr._locate_default_gem).realpath,
      [gem_name, bin_name],
  )


# Commands installed together with ruby command.
_DEFAULT_SCRIPTS = [
    ("irb", "irb"),
    ("rdoc", "rdoc"),
    ("rdoc", "ri"),
    ("erb", "erb"),
    ("rake", "rake"),
    ("rubygems", "gem"),
]

def _install_host_ruby(ctx, ruby):
  # Places SDK
  ctx.symlink(ctx.attr._init_loadpath_rb, "init_loadpath.rb")
  ctx.symlink(ruby.interpreter_realpath, ruby.rel_interpreter_path)

  script_mappings = {}
  for (gem_name, bin_name) in _DEFAULT_SCRIPTS:
    script_path = _locate_script(ctx, ruby, gem_name, bin_name)
    if not script_path:
      print("Falling back to bindir")
      script_path = _bin_install_path(ruby, bin_name)
    if not script_path:
      fail("Failed to locate %s" % bin_name)

    rel_script_path = _relativate(script_path)
    script_mappings[bin_name] = rel_script_path
    ctx.symlink(script_path, rel_script_path)

  # Places the interpreter at a predictable place regardless of the actual binary name
  # so that bundle_install can depend on it.
  ctx.template(
      "ruby",
      ctx.attr._interpreter_wrapper_template,
      substitutions = {
          '{workspace_name}': ctx.name,
          '{rel_interpreter_path}': ruby.rel_interpreter_path,
      }
  )

  # Install lib
  paths, rel_paths = _list_libdirs(ruby)
  for i, (path, rel_path) in enumerate(zip(paths, rel_paths)):
    if not _is_subpath(rel_path, rel_paths[:i]):
      ctx.symlink(path, rel_path)

  # Install libruby
  static_library = ruby.expand_rbconfig(ruby, '${libdir}/${LIBRUBY_A}')
  if ctx.path(static_library).exists:
    ctx.symlink(static_library, _relativate(static_library))
  else:
    static_library = None

  shared_library = ruby.expand_rbconfig(ruby, '${libdir}/${LIBRUBY_SO}')
  if ctx.path(shared_library).exists:
    ctx.symlink(shared_library, _relativate(shared_library))
  else:
    shared_library = None

  ctx.file("loadpath.lst", "\n".join(rel_paths))
  return struct(
      includedirs = _install_dirs(ctx, ruby, "rubyarchhdrdir", "rubyhdrdir"),
      libdirs = rel_paths,
      static_library = _relativate(static_library),
      shared_library = _relativate(shared_library),
      script_mappings = script_mappings
  )


def _ruby_host_runtime_impl(ctx):
  # Locates path to the interpreter
  if ctx.attr.interpreter_path:
    interpreter_path = ctx.path(ctx.attr.interpreter_path)
  else:
    interpreter_path = ctx.which("ruby")
  if not interpreter_path:
    fail(
        "Command 'ruby' not found. Set $PATH or specify interpreter_path",
        "interpreter_path",
    )

  ruby = ruby_repository_context(ctx, interpreter_path)

  installed = _install_host_ruby(ctx, ruby)
  install_bundler(
      ruby,
      interpreter_path,
      ctx.path(ctx.attr._install_bundler).realpath,
      'bundler',
  )

  ctx.template(
      'BUILD.bazel',
      ctx.attr._buildfile_template,
      substitutions = {
          "{ruby_path}": repr(ruby.rel_interpreter_path),
          "{ruby_basename}": repr(ruby.interpreter_name),
          "{includes}": repr(installed.includedirs),
          "{hdrs}": repr(["%s/**/*.h" % path for path in installed.includedirs]),
          "{static_library}": repr(installed.static_library),
          "{shared_library}": repr(installed.shared_library),
          "{irb}": repr(installed.script_mappings["irb"]),
          "{rdoc}": repr(installed.script_mappings["rdoc"]),
          "{ri}": repr(installed.script_mappings["ri"]),
          "{erb}": repr(installed.script_mappings["erb"]),
          "{rake}": repr(installed.script_mappings["rake"]),
          "{gem}": repr(installed.script_mappings["gem"]),
          "{rules_ruby_workspace}": RULES_RUBY_WORKSPACE_NAME,
      },
      executable = False,
  )

ruby_host_runtime = repository_rule(
    implementation = _ruby_host_runtime_impl,
    attrs = {
        "interpreter_path": attr.string(),

        "_init_loadpath_rb": attr.label(
            default = "%s//:ruby/tools/init_loadpath.rb" % (
                RULES_RUBY_WORKSPACE_NAME),
            allow_single_file = True,
        ),
        "_install_bundler": attr.label(
            default = "%s//ruby/private:install-bundler.rb" % (
                RULES_RUBY_WORKSPACE_NAME),
            allow_single_file = True,
        ),
        "_locate_default_gem": attr.label(
            default = "%s//ruby/private:locate_default_gem.rb" % (
                RULES_RUBY_WORKSPACE_NAME),
            allow_single_file = True,
        ),
        "_buildfile_template": attr.label(
            default = "%s//ruby/private:BUILD.host_runtime.tpl" % (
                RULES_RUBY_WORKSPACE_NAME),
            allow_single_file = True,
        ),
        "_interpreter_wrapper_template": attr.label(
            default = "%s//ruby/private:interpreter_wrapper.tpl" % (
                RULES_RUBY_WORKSPACE_NAME),
            allow_single_file = True,
        ),
    },
)
