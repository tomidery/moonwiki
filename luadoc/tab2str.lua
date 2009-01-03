-----------------------------------------------------------------------------
-- Tab2str: Table to String.
-- Produce a string with Lua code that can rebuild the given table.

-----------------------------------------------------------------------------
-- "Imprime" uma tabela em uma string.
-- Os campos s�o gerados na ordem que vierem da fun��o next.
-- Os campos de valores num�ricos n�o s�o separados dos campos "string"
-- e os outros tipos (userdata, fun��o e tabela) s�o ignorados.
-- Se o par�metro [[spacing]] for nulo, � considerado como se fosse [[""]].
-- caso contr�rio, seu valor � usado na indenta��o e um [[\n]] � acrescentado
-- entre os elementos.
-- Cada tabela listada ganha um n�mero (indicado entre [[<]] e [[>]],
-- logo depois da [[{]] inicial) que serve para refer�ncia cruzada de
-- tabelas j� listadas.  Neste caso, as tabelas j� listadas s�o
-- representadas por [[{@]] seguido do n�mero da tabela e [[}]].
-- @param t N�mero a ser "impresso".
-- @param spacing String de espa�amento entre elementos da tabela.
-- @param indent String com a indenta��o inicial (este par�metro � utilizado
--	pela pr�pria fun��o para acumular a indenta��o de tabelas internas).
-- @return String com o resultado.

function tab2str (t, spacing, indent)
   local tipo = type (t)
   if tipo == "string" then
      return format ("%q",t)
   elseif tipo == "number" then
      return t
   elseif tipo == "table" then
      if _table_ then
         if _table_[t] then
            return "{@".._table_[t].."}"
         else
            _table_.n = _table_.n + 1
            _table_[t] = _table_.n
         end
      end
      local aux = ""
      local s = "{"
      if _table_ then
         s = s.."<".._table_[t]..">"
      end
      if not indent then
         indent = ""
      end
      if spacing then
         aux = indent .. spacing
      end
      local i,v
      i, v = next (t, nil)
      while i do
         if spacing then
            s = s .. '\n' .. aux
         end
         local t_i = type(i)
         if t_i == "number" or t_i == "string" then
            s = string.format ("%s[%s] = %s,", s, tab2str (i), tab2str (v, spacing, aux))
         end
         i, v = next (t, i)
      end
      if spacing then
         s = s .. '\n' .. indent
      end
      return s .. "}"
   else
      return "<"..tipo..">"
   end
end

function t2s (t, s, i)
   local old_table = _table_
   _table_ = { n = 0 }
   local result = tab2str (t, s, i)
   _table_ = old_table
   return result
end
