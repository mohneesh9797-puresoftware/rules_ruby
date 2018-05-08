def _eval_ruby(ruby, script, options=None):
  arguments = ['env', '-i', ruby.interpreter_realpath]
  if options:
    arguments.extend(options)
  arguments.extend(['-e', script])

  environment = {"RUBYOPT": "--disable-gems"}

  result = ruby._ctx.execute(arguments, environment=environment)
  if result.return_code:
    message = "Failed to evaluate ruby snippet with {}: {}".format(
        ruby.interpreter_realpath, result.stderr)
    fail(message)
  return result.stdout


def _rbconfig(ruby, name):
  options = ['-rrbconfig']
  script = 'print RbConfig::CONFIG[{}]'.format(
      # Here we actually needs String#dump in Ruby but
      # repr in Python is compatible enough.
      repr(name),
  )
  _eval_ruby(ruby, script=script, options=options)


def ruby_repository_context(repository_ctx, interpreter_path):
  interpreter_path = interpreter_path.realpath
  interpreter_name = interpreter_path.basename

  rel_interpreter_path = str(interpreter_path)
  if rel_interpreter_path.startswith('/'):
    rel_interpreter_path = rel_interpreter_path[1:]

  return struct(
      # Location of the interpreter
      rel_interpreter_path = rel_interpreter_path,
      interpreter_name = interpreter_path.basename,
      interpreter_realpath = interpreter_path,

      # Standard repository structure for ruby runtimes

      # Helper methods
      eval = _eval_ruby,
      rbconfig = _rbconfig,

      _ctx = repository_ctx,
  )
