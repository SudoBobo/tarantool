fiber = require('fiber')

--
-- gh-2784: do not validate space formatted but not indexed fields
-- in surrogate statements.
--

-- At first, test simple surrogate delete generated from a key.
format = {{name = 'a', type = 'unsigned'}, {name = 'b', type = 'unsigned'}}
s = box.schema.space.create('test', {engine = 'vinyl', format = format})
_ = s:create_index('pk')
s:insert{1, 1}
-- Type of a second field in a surrogate tuple must be NULL but
-- with UNSIGNED type, specified in a tuple_format. It is
-- possible, because only indexed fields are used in surrogate
-- tuples.
s:delete(1)
s:drop()

-- Test select after snapshot. This select gets surrogate
-- tuples from a disk. Here NULL also can be stored in formatted,
-- but not indexed field.
format = {}
format[1] = {name = 'a', type = 'unsigned'}
format[2] = {name = 'b', type = 'unsigned'}
format[3] = {name = 'c', type = 'unsigned'}
s = box.schema.space.create('test', {engine = 'vinyl', format = format})
_ = s:create_index('pk')
_ = s:create_index('sk', {parts = {2, 'unsigned'}})
s:insert{1, 1, 1}
box.snapshot()
s:delete(1)
box.snapshot()
s:select()
s:drop()

--
-- gh-2983: ensure the transaction associated with a fiber
-- is automatically rolled back if the fiber stops.
--
s = box.schema.create_space('test', { engine = 'vinyl' })
_ = s:create_index('pk')
tx1 = box.info.vinyl().tx
ch = fiber.channel(1)
_ = fiber.create(function() box.begin() s:insert{1} ch:put(true) end)
ch:get()
tx2 = box.info.vinyl().tx
tx2.commit - tx1.commit -- 0
tx2.rollback - tx1.rollback -- 1
s:drop()
