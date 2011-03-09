#include <locale.h>
#include "ruby.h"

static VALUE mLocale;

static VALUE
locale_setlocale(obj)
{
  setlocale(LC_CTYPE, "");
#ifdef LC_MESSAGES
  setlocale(LC_MESSAGES, "");
#endif
  return Qnil;
}

static VALUE
locale_setlocale2(obj, str)
  VALUE str;
{
  char *s = StringValuePtr(str);
  setlocale(LC_CTYPE, s);
#ifdef LC_MESSAGES
  setlocale(LC_MESSAGES, s);
#endif
  return Qnil;
}

void
Init_locale()
{
  mLocale = rb_define_module("Locale");
  rb_define_module_function(mLocale, "setlocale", locale_setlocale, 0);
  rb_define_module_function(mLocale, "setlocale2", locale_setlocale2, 1);
}
