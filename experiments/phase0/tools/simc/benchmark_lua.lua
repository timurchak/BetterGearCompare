-- Execute the generated surrogate in a stock Lua 5.1 runtime.
local modelPath = assert(arg[1], "usage: lua benchmark_lua.lua MODEL_PATH")
local model = assert(dofile(modelPath))

local vectors = {
  {1950, 650, 700, 800, 850},
  {1750, 1100, 500, 650, 700},
  {2250, 450, 900, 1200, 750},
  {2050, 950, 1000, 550, 600},
  {1850, 700, 550, 950, 1050},
}

local values = {}
for index, vector in ipairs(vectors) do
  values[index] = assert(model:Evaluate(unpack(vector)))
end

local iterations = 1000000
local accumulator = 0
local started = os.clock()
for index = 1, iterations do
  local vector = vectors[((index - 1) % #vectors) + 1]
  accumulator = accumulator + assert(model:Evaluate(unpack(vector)))
end
local elapsed = os.clock() - started
local outside, outsideReason = model:Evaluate(100, 1, 1, 1, 1)

io.write('{"schema":1,"runtime":"Lua 5.1.5","iterations":', iterations)
io.write(',"elapsedSeconds":', string.format("%.9f", elapsed))
io.write(',"microsecondsPerEvaluation":', string.format("%.9f", elapsed / iterations * 1000000))
io.write(',"accumulator":', string.format("%.17g", accumulator))
io.write(',"outOfDomainRejected":', outside == nil and "true" or "false")
io.write(',"outOfDomainReason":"', tostring(outsideReason), '","vectors":[')
for index, vector in ipairs(vectors) do
  if index > 1 then io.write(',') end
  io.write('{"input":[')
  for dimension, value in ipairs(vector) do
    if dimension > 1 then io.write(',') end
    io.write(value)
  end
  io.write('],"logScore":', string.format("%.17g", values[index]), '}')
end
io.write(']}\n')

