#ifndef TH_GENERIC_FILE
#define TH_GENERIC_FILE "generic/SoftPlus.c"
#else

static int nn_(SoftPlus_forward)(lua_State *L)
{
  THTensor *input = luaT_checkudata(L, 2, torch_(Tensor_id));
  THTensor *output = luaT_getfieldcheckudata(L, 1, "output", torch_(Tensor_id));
  
  THTensor_(resizeAs)(output, input);

  TH_TENSOR_APPLY2(real, output, real, input,               \
                   *output_data = log1p(exp(*input_data));)
    
    return 1;
}

static int nn_(SoftPlus_updateGradInput)(lua_State *L)
{
  THTensor *gradOutput = luaT_checkudata(L, 3, torch_(Tensor_id));
  THTensor *output = luaT_getfieldcheckudata(L, 1, "output", torch_(Tensor_id));
  THTensor *gradInput = luaT_getfieldcheckudata(L, 1, "gradInput", torch_(Tensor_id));

  THTensor_(resizeAs)(gradInput, output);
  TH_TENSOR_APPLY3(real, gradInput, real, gradOutput, real, output,    \
                   real z = exp(*output_data);                         \
                   *gradInput_data = *gradOutput_data * (z - 1.)/z;)
    return 1;
}

static const struct luaL_Reg nn_(SoftPlus__) [] = {
  {"SoftPlus_forward", nn_(SoftPlus_forward)},
  {"SoftPlus_updateGradInput", nn_(SoftPlus_updateGradInput)},
  {NULL, NULL}
};

static void nn_(SoftPlus_init)(lua_State *L)
{
  luaT_pushmetaclass(L, torch_(Tensor_id));
  luaT_registeratname(L, nn_(SoftPlus__), "nn");
  lua_pop(L,1);
}

#endif
