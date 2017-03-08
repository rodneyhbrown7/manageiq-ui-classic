if [ "$TEST_SUITE" = "spec" ]; then
  bundle exec codeclimate-test-reporter;
fi

# Collapse Travis output https://github.com/travis-ci/travis-ci/issues/2158
echo "travis_fold:start:GEMFILE_LOCK"
bundle show
echo "travis_fold:end:GEMFILE_LOCK"
