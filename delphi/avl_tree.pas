unit avl_tree;

interface
  uses SysUtils, Math;

type
  Pavl_node = ^Tavl_node;
  Tavl_node = record
      parent, left, right : Pavl_node;
      bf : integer;
      prev, next : Pavl_node;
  end;

  {$IFDEF _LAMBDA_CALLBACK}
  Tavl_cmp_func = TFunc<Pavl_node, Pavl_node, Pointer, integer>;
  {$ELSE}
  Tavl_cmp_func = function(a,b : Pavl_node; aux: Pointer) : integer;
  {$ENDIF}

  pavl_tree = ^Tavl_tree;
  Tavl_tree = record
      root : Pavl_node;
      func: Tavl_cmp_func;
      aux : Pointer;
  end;


  function avl_first( tree : pavl_tree):Pavl_node;
  function avl_last( tree : pavl_tree):Pavl_node;
  function avl_next( node : pavl_node):Pavl_node;
  function avl_prev( node : pavl_node):Pavl_node;
  function avl_search( tree : pavl_tree; node : pavl_node):Pavl_node;
  function avl_search_greater( tree : pavl_tree; node : pavl_node):Pavl_node;
  function avl_search_smaller( tree : pavl_tree; node : pavl_node):Pavl_node;
  procedure avl_init( tree : pavl_tree);
  function avl_insert( tree : pavl_tree; node : pavl_node):Pavl_node;
  procedure avl_remove( tree : pavl_tree; node : pavl_node);

implementation

function ifthen(b: Boolean;a1,a2 : integer) : integer; inline;
begin
   if b then
     result := a1
   else
     result := a2;
end;

procedure avl_set_parent(node: Pavl_node; parent: Pavl_node); inline;
begin
  node.parent := parent;
end;

procedure avl_set_bf(node: Pavl_node; abf: integer); inline;
begin
  node.bf := abf;
end;

function avl_bf(node: Pavl_node) : integer; inline;
begin
  result := node.bf;
end;

function _get_balance(node : pavl_node) : integer; inline;
begin
  if node=nil then
     result := 0
  else
    result := avl_bf(node);
end;

function avl_parent(node: Pavl_node) : Pavl_node; inline;
begin
  result := node.parent;
end;


function _rotate_LL(parent : pavl_node; parent_bf : integer;child_bf, height_delta : Pinteger):Pavl_node;
var
  p_right, c_left, c_right : integer;
  child : pavl_node;
begin
    child := parent.left;
    c_left := ifthen(child.left<>nil,1,0);
    c_right := ifthen(child.right<>nil,1,0);
    if child_bf^ < 0 then
    begin
        c_left := c_right - ( child_bf^);
        p_right := c_left + 1 + parent_bf;
        if height_delta<>nil then
           height_delta^ := max(c_left, max(c_right, p_right)+1) - (c_left + 1);
    end
    else
    begin
        c_right := c_left + ( child_bf^);
        p_right := c_right + 1 + parent_bf;
        if height_delta<>nil then
           height_delta^ := max(c_left, max(c_right, p_right)+1) - (c_right + 1);
    end;
    child_bf^ := (max(c_right, p_right) + 1) - c_left;
    parent.bf :=  p_right - c_right;
    parent.left := child.right;
    if child.right<>nil then avl_set_parent(child.right, parent);
    child.right := parent;
    avl_set_parent(child, avl_parent(parent));
    avl_set_parent(parent, child);
    Result := child;
end;


function _rotate_RR(parent : pavl_node; parent_bf : integer; child_bf, height_delta : Pinteger):Pavl_node;
var
  p_left, c_left, c_right : integer;
  child : pavl_node;
begin
    child := parent.right;
    c_left := ifthen(child.left<>nil,1,0);
    c_right := ifthen(child.right<>nil,1,0);
    if child_bf^ < 0 then
    begin
        c_left := c_right - ( child_bf^);
        p_left := c_left + 1 - parent_bf;
        if height_delta<>nil then
           height_delta^ := max(c_right, max(c_left, p_left)+1) - (c_left + 1);
    end
    else
    begin
        c_right := c_left + ( child_bf^);
        p_left := c_right + 1 - parent_bf;
        if height_delta<>nil then
           height_delta^ := max(c_right, max(c_left, p_left)+1) - (c_right + 1);
    end;
    child_bf^ := c_right - (max(c_left, p_left) + 1);
    avl_set_bf(parent, c_left - p_left);
    parent.right := child.left;
    if child.left<>nil then avl_set_parent(child.left, parent);
    child.left := parent;
    avl_set_parent(child, avl_parent(parent));
    avl_set_parent(parent, child);
    Result := child;
end;


function _rotate_LR( parent : pavl_node; parent_bf : integer):Pavl_node;
var
  child_bf,
  height_delta : integer;
  child,
  ret          : pavl_node;
begin
    height_delta := 0;
    child := parent.left;
    if child.right<>nil then
    begin
        child_bf := avl_bf(child.right);
        parent.left := _rotate_RR(child, avl_bf(child), @child_bf, @height_delta);
    end
    else
    begin
        child_bf := avl_bf(child);
    end;
    ret := _rotate_LL(parent, parent_bf-height_delta, @child_bf, nil);
    avl_set_bf(ret, child_bf);
    Result := ret;
end;


function _rotate_RL( parent : pavl_node; parent_bf : integer):Pavl_node;
var
  child_bf,
  height_delta : integer;
  child,
  ret          : pavl_node;
begin
    height_delta := 0;
    child := parent.right;
    if child.left<>nil then
    begin
        child_bf := avl_bf(child.left);
        parent.right := _rotate_LL(child, avl_bf(child), @child_bf, @height_delta);
    end
    else
    begin
        child_bf := avl_bf(child);
    end;
    ret := _rotate_RR(parent, parent_bf+height_delta, @child_bf, nil);
    avl_set_bf(ret, child_bf);
    Result := ret;
end;

function _balance_tree( node : pavl_node; bf : integer):Pavl_node;
var
  child_bf,
  height_diff : integer;
begin
    height_diff := _get_balance(node) + bf;
    if node<>nil then
    begin
        if (height_diff < -1) and (node.left<>nil) then
        begin
            if _get_balance(node.left) <= 0 then
            begin
                child_bf := avl_bf(node.left);
                node := _rotate_LL(node, height_diff, @child_bf, nil);
                avl_set_bf(node, child_bf);
            end
            else
            begin
                node := _rotate_LR(node, height_diff);
            end;
        end
        else
        if (height_diff > 1) and (node.right <> nil) then
        begin
            if _get_balance(node.right) >= 0 then
            begin
                child_bf := avl_bf(node.right);
                node := _rotate_RR(node, height_diff, @child_bf, nil);
                avl_set_bf(node, child_bf);
            end
            else
            begin
              node := _rotate_RL(node, height_diff);
            end;
        end
        else
        begin
          avl_set_bf(node, avl_bf(node) + bf);
        end;
    end;
    Result := node;
end;


function avl_first( tree : pavl_tree):Pavl_node;
var
  p, node : pavl_node;
begin
    p := nil;
    node := tree.root;
    while node<>nil do
     begin
        p := node;
        node := node.left;
    end;
    Result := p;
end;


function avl_last( tree : pavl_tree):Pavl_node;
var
  p, node : pavl_node;
begin
    p := nil;
    node := tree.root;
    while node<>nil do
    begin
        p := node;
        node := node.right;
    end;
    Result := p;
end;


function avl_next( node : pavl_node):Pavl_node;
begin
    if node = nil then Exit(nil);
    Result := node.next;
end;


function avl_prev( node : pavl_node):Pavl_node;
begin
    if node = nil then Exit(nil);
    Result := node.prev;
end;


function avl_search( tree : pavl_tree; node : pavl_node):Pavl_node;
var
  p : pavl_node;
  cmp : integer;
begin
    p := tree.root;
    while p<>nil do
    begin
        cmp := tree.func(p, node, tree.aux);
        if cmp > 0 then
        begin
          p := p.left;
        end
        else
        if (cmp < 0) then
        begin
          p := p.right;
        end
       else
       begin
         Exit(p);
       end;
    end;
    Result := nil;
end;


function avl_search_greater( tree : pavl_tree; node : pavl_node):Pavl_node;
var
  p, pp : pavl_node;
  cmp : integer;
begin
    p := tree.root;
    pp := nil;
    while p<>nil do
    begin
        cmp := tree.func(p, node, tree.aux);
        pp := p;
        if cmp > 0 then
        begin
            p := p.left;
        end
        else
        if (cmp < 0) then
        begin
          p := p.right;
        end
        else
        begin
          Exit(p);
        end;
    end;
    if pp=nil then
    begin
      Exit(nil);
    end;
    cmp := tree.func(pp, node, tree.aux);
    if cmp > 0 then
    begin
      Exit(pp);
    end
    else
    begin
      Exit(avl_next(pp));
    end;
end;


function avl_search_smaller( tree : pavl_tree; node : pavl_node):Pavl_node;
var
  p, pp : pavl_node;
  cmp : integer;
begin
    p := tree.root;
    pp := nil;
    while p<>nil do
    begin
        cmp := tree.func(p, node, tree.aux);
        pp := p;
        if cmp > 0 then
        begin
            p := p.left;
        end
        else
        if (cmp < 0) then
        begin
          p := p.right;
        end
        else
        begin
           Exit(p);
        end;
    end;
    if pp=nil then
    begin
        Exit(nil);
    end;
    cmp := tree.func(pp, node, tree.aux);
    if cmp < 0 then
    begin
       Exit(pp);
    end
    else
    begin
        Exit(avl_prev(pp));
    end;
end;


procedure avl_init( tree : pavl_tree);
begin
    tree.root := nil;
    tree.aux := nil;
end;


function avl_insert( tree : pavl_tree; node : pavl_node):Pavl_node;
var
  node_original,
  p,
  cur            : pavl_node;
  cmp,
  bf,
  bf_old        : integer;
begin
    node_original := node;
    p := nil;
    cur := tree.root;
    while cur<> nil do
    begin
        cmp := tree.func(cur, node, tree.aux);
        p := cur;
        if cmp > 0 then
        begin
           cur := cur.left;
        end
        else
        if (cmp < 0) then
        begin
          cur := cur.right;
        end
        else
        begin
          Exit(cur);
        end;
    end;
    avl_set_parent(node, p);
    avl_set_bf(node, 0);
    node.left := nil;
    node.right := nil;
    node.prev := nil;
    node.next := nil;
    if p<>nil then
    begin
        if tree.func(p, node, tree.aux) > 0 then
        begin
            p.left := node;
            node.next := p;
            node.prev := p.prev;
            if p.prev<>nil then
              p.prev.next := node;
            p.prev := node;
        end
        else
        begin
            p.right := node;
            node.prev := p;
            node.next := p.next;
            if p.next<>nil then
               p.next.prev := node;
            p.next := node;
        end;
    end
    else
    begin
        tree.root := node;
    end;
    // recursive balancing process .. scan from leaf to root
    bf := 0;
    while node<>nil do
    begin
        p := avl_parent(node);
        if p<>nil then
        begin
            bf_old := avl_bf(node);
            if p.right = node then
            begin
                node := _balance_tree(node, bf);
                p.right := node;
            end
            else
            begin
                node := _balance_tree(node, bf);
                p.left := node;
            end;
            // calculate balance facter BF for parent
            if (node.left = nil)  and (node.right = nil) then
            begin
                // leaf node
                if p.left = node then
                   bf := -1
                else
                  bf := 1;
            end
            else
            begin
                // index ndoe
                bf := 0;
                if abs(bf_old) < abs(avl_bf(node)) then
                begin
                    // if ABS of balance factor increases
                    // cascade to parent
                    if p.left = node then
                       bf := -1
                    else
                       bf := 1;
                end;
            end;
        end
        else
        if(node = tree.root) then
        begin
            tree.root := _balance_tree(tree.root, bf);
            break;
        end;
        if bf = 0 then break;
        node := p;
    end;
    Result := node_original;
end;


procedure avl_remove( tree : pavl_tree; node : pavl_node);
var
  right_subtree : Tavl_tree;
  p, cur, next  : pavl_node;
  bf, bf_old    : integer;
begin
    if node = nil then exit;
    p := nil;
    next:=nil;
    cur :=nil;
    bf := 0;
    if node.prev<>nil then node.prev.next := node.next;
    if node.next<>nil then node.next.prev := node.prev;
    right_subtree.root := node.right;
    right_subtree.func := tree.func;
    next := avl_first(@right_subtree);
    if next <> nil then
    begin
        // 1. NEXT exists
        if avl_parent(next) <> nil then
        begin
            if avl_parent(next) <> node then
            begin
                avl_parent(next).left := next.right;
                if next.right<>nil then
                  avl_set_parent(next.right, avl_parent(next));
            end;
        end;
        if avl_parent(node)<>nil then
        begin
            // replace NODE by NEXT
            if avl_parent(node).left = node then
            begin
                avl_parent(node).left := next;
            end
            else
            begin
                avl_parent(node).right := next;
            end;
        end;
        // re-link pointers
        if node.right <> next then
        begin
            next.right := node.right;
            if node.right<>nil then
               avl_set_parent(node.right, next);
            cur := avl_parent(next);
            bf := 1;
        end
        else
        begin
            cur := next;
            bf := -1;
        end;
        next.left := node.left;
        if node.left<>nil then avl_set_parent(node.left, next);
        avl_set_parent(next, avl_parent(node));

        // inherit NODE's balance factor
        avl_set_bf(next, avl_bf(node));
    end
    else
    begin
        // 2. NEXT == NULL (only when there's no right sub-tree)
        p := avl_parent(node);
        if p<>nil then
        begin
            if p.left = node then
            begin
                p.left := node.left;
                bf := 1;
            end
            else
            begin
                p.right := node.left;
                bf := -1;
            end;
        end;
        if node.left<>nil then avl_set_parent(node.left, p);
        cur := avl_parent(node);
    end;

    // reset root
    if tree.root = node then
    begin
        tree.root := next;
        if next = nil then
        begin
           if node.left<>nil then
             tree.root := node.left;
        end;
    end;

    // recursive balancing process .. scan from CUR to root
    while cur<>nil do
    begin
        p := avl_parent(cur);
        if p<>nil then
        begin
            bf_old := avl_bf(cur);
            if p.right = cur then
            begin
                cur := _balance_tree(cur, bf);
                p.right := cur;
            end
            else
            begin
                cur := _balance_tree(cur, bf);
                p.left := cur;
            end;

            // calculate balance facter BF for parent
            if (cur.left = nil)  and  (cur.right = nil) then
            begin
               // leaf node
                if p.left = cur then
                  bf := 1
                else
                  bf := -1;
            end
            else
            begin
                // index ndoe
                bf := 0;
                if abs(bf_old) > abs(avl_bf(cur)) then
                begin
                    if p.left = cur then
                       bf := 1
                    else
                      bf := -1;
                end;
            end;
        end
        else
        if(cur = tree.root) then
        begin
            tree.root := _balance_tree(tree.root, bf);
            break;
        end;
        if bf = 0 then break;
        cur := p;
    end;
end;

end.
