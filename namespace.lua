local _, ns = ...;

local namespace = {};

setmetatable(ns,{
	--__metatable = false
	__newindex = function(t,k,v)
		namespace[k]=v;
	end,
	__index = function(t,k)
		return namespace[k];
	end,
});

-- sometimes lua errors are filled with functions and tables from namespace
-- and __metatable does not work for lua errors.
-- this should prevent it.


