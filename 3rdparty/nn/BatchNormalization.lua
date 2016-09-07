--[[
   This file implements Batch Normalization as described in the paper:
   "Batch Normalization: Accelerating Deep Network Training
                         by Reducing Internal Covariate Shift"
                   by Sergey Ioffe, Christian Szegedy

   This implementation is useful for inputs NOT coming from convolution layers.
   For convolution layers, use nn.SpatialBatchNormalization.

   The operation implemented is:
   y =     ( x - mean(x) )
        -------------------- * gamma + beta
        standard-deviation(x)
   where gamma and beta are learnable parameters.

   The learning of gamma and beta is optional.

   Usage:
   with    learnable parameters: nn.BatchNormalization(N [,eps] [,momentum])
                                 where N = dimensionality of input
   without learnable parameters: nn.BatchNormalization(N [,eps] [,momentum], false)

   eps is a small value added to the standard-deviation to avoid divide-by-zero.
       Defaults to 1e-5

   In training time, this layer keeps a running estimate of it's computed mean and std.
   The running sum is kept with a default momentum of 0.1 (unless over-ridden)
   In test time, this running mean/std is used to normalize.
]]--
local BN,parent = torch.class('nn.BatchNormalization', 'nn.Module')

BN.__version = 2

-- expected dimension of input
BN.nDim = 2

function BN:__init(nOutput, eps, momentum, affine)
   parent.__init(self)
   assert(nOutput and type(nOutput) == 'number',
          'Missing argument #1: dimensionality of input. ')
   assert(nOutput ~= 0, 'To set affine=false call BatchNormalization'
     .. '(nOutput,  eps, momentum, false) ')
   if affine ~= nil then
      assert(type(affine) == 'boolean', 'affine has to be true/false')
      self.affine = affine
   else
      self.affine = true
   end
   self.eps = eps or 1e-5
   self.train = true
   self.momentum = momentum or 0.1
   self.running_mean = torch.zeros(nOutput)
   self.running_var = torch.ones(nOutput)

   if self.affine then
      self.weight = torch.Tensor(nOutput)
      self.bias = torch.Tensor(nOutput)
      self.gradWeight = torch.Tensor(nOutput)
      self.gradBias = torch.Tensor(nOutput)
      self:reset()
   end
end

function BN:reset()
   if self.weight then
      self.weight:uniform()
   end
   if self.bias then
      self.bias:zero()
   end
   self.running_mean:zero()
   self.running_var:fill(1)
end

function BN:checkInputDim(input)
   local iDim = input:dim()
   assert(iDim == self.nDim or
              (iDim == self.nDim - 1 and self.train == false), string.format(
      'only mini-batch supported (%dD tensor), got %dD tensor instead',
      self.nDim, iDim))
   local featDim = (iDim == self.nDim - 1) and 1 or 2
   assert(input:size(featDim) == self.running_mean:nElement(), string.format(
      'got %d-feature tensor, expected %d',
      input:size(featDim), self.running_mean:nElement()))
end

local function makeContiguous(self, input, gradOutput)
   if not input:isContiguous() then
      self._input = self._input or input.new()
      self._input:resizeAs(input):copy(input)
      input = self._input
   end
   if gradOutput then
      if not gradOutput:isContiguous() then
         self._gradOutput = self._gradOutput or gradOutput.new()
         self._gradOutput:resizeAs(gradOutput):copy(gradOutput)
         gradOutput = self._gradOutput
      end
   end
   return input, gradOutput
end

local function makeBatch(self, input)
    local iDim = input:dim()
    if self.train == false and iDim == self.nDim - 1 then
        return nn.utils.addSingletonDimension(input, input, 1)
    else
        return input
    end
end

function BN:updateOutput(input)
   self:checkInputDim(input)

   input = makeContiguous(self, input)
   input = makeBatch(self, input)

   self.output:resizeAs(input)
   self.save_mean = self.save_mean or input.new()
   self.save_mean:resizeAs(self.running_mean)
   self.save_std = self.save_std or input.new()
   self.save_std:resizeAs(self.running_var)

   input.nn.BatchNormalization_updateOutput(self, input)

   return self.output
end

function BN:updateGradInput(input, gradOutput)
    return nil
end

function BN:accGradParameters(input, gradOutput, scale)
    return nil
end

function BN:read(file, version)
   parent.read(self, file)
   if version < 2 then
      if self.running_std then
         self.running_var = self.running_std:pow(-2):add(-self.eps)
         self.running_std = nil
      end
   end
end
