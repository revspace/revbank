package RevBank::Eval;

# This function is used so strings can be eval'ed in a clean lexical
# environment.

sub clean_eval { eval shift }

# No, it's not scary. We're using string eval to load plugins, just as it would
# be used to load modules. As we're not executing user input, this is really
# NOT a security bug.

1;

