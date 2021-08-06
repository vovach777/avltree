program avl_example;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  avl_tree in 'avl_tree.pas';


type
  Pkv_node = ^Tkv_node;
  Tkv_node = record
    avl : Tavl_node;
    key:integer;
    value:integer;
  end;

function cmp_func(a,b: Pavl_node; aux: Pointer) : integer;
begin
  if Pkv_node(a).key < Pkv_node(b).key then
     result := -1
  else
  if Pkv_node(a).key > Pkv_node(b).key then
     result := 1
  else
     result := 0;
end;

var
  tree : Tavl_tree;
  query : Tkv_node;
  node: Pkv_node;
  cur : Pavl_node;

  i, prev_key : integer;
const
   n = 30000000;
begin
  try
    randomize;
    avl_init(@tree);
    query := default(Tkv_node);
    tree.func := cmp_func;
    for i :=0 to n-1 do
    begin
      new(node);
      node^ := default(Tkv_node);
      node.key := random(n*10);
      node.value := 0;
      cur := avl_insert(@tree,@node.avl);
      if cur <> @node.avl then
      begin
        dispose(node);
        inc( pkv_node( cur ).value );
        if pkv_node( cur ).value > 2 then
          WriteLn(Format('duplicate: key %d, value %d', [pkv_node( cur ).key, pkv_node( cur ).value]));
      end;
    end;
    // retrieve each key-value pair by key
    WriteLn('retrieve by key');
    for i:=0 to n*10-1 do
    begin
        query.key := i;
        node := pkv_node( avl_search(@tree, @query.avl) );
//        if node<> nil then
//          WriteLn(Format('key %d, value %d', [node.key, node.value]));
    end;

    WriteLn('remove all key-value pairs');
    // remove all key-value pairs
    cur := avl_first(@tree);
    prev_key := -1;
    while(cur<>nil) do
    begin
        node := pkv_node(cur);
        assert( node.key > prev_key, 'failed order!' );
        prev_key := node.key;
        //WriteLn(Format('remove key %d, value %d',[node.key, node.value]));
        cur := avl_next(cur);
        avl_remove(@tree, @node.avl);
        dispose(node);
    end;

    WriteLn('Done!');
    readln;


  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
