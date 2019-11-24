workspace(name = "bazelruby_ruby_rules")

load("@//ruby:deps.bzl", "ruby_register_toolchains", "ruby_rules_dependencies")

ruby_rules_dependencies()

ruby_register_toolchains()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

local_repository(
    name = "bazelruby_ruby_rules_ruby_tests_testdata_another_workspace",
    path = "ruby/tests/testdata/another_workspace",
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_pkg",
    sha256 = "4ba8f4ab0ff85f2484287ab06c0d871dcb31cc54d439457d28fd4ae14b18450a",
    url = "https://github.com/bazelbuild/rules_pkg/releases/download/0.2.4/rules_pkg-0.2.4.tar.gz",
)

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "8dc1466f8563f3aa4ac7ab7aa3c96651eb7764108219f40b2d1c918e1a81c601",
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/0.41.0/rules_nodejs-0.41.0.tar.gz"],
)

load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories")

node_repositories(
    package_json = ["//ruby:package.json"],
)
