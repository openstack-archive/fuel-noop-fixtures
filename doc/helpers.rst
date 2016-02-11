Using additional RSpec matchers and task helpers
================================================

There are some matchers for RSpec one would like to use

ensure_transitive_dependency(before, after)
-------------------------------------------

This matcher allows one to check whether there is a
dependency between *after* and *before* resources
even if this dependency is transitional by means
of several other resources or containers such
as classes or defines.
