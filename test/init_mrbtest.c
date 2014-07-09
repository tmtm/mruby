#include <stdlib.h>
#include "mruby.h"
#include "mruby/irep.h"

extern const uint8_t mrbtest_assert_irep[];
extern const uint8_t mrbtest_irep[];

void mrbgemtest_init(mrb_state* mrb);

void
mrb_init_mrbtest(mrb_state *mrb)
{
  mrb_load_irep(mrb, mrbtest_assert_irep);
  mrb_load_irep(mrb, mrbtest_irep);
#ifndef DISABLE_GEMS
  mrbgemtest_init(mrb);
#endif
  if (mrb->exc) {
    mrb_print_error(mrb);
    exit(EXIT_FAILURE);
  }
}

