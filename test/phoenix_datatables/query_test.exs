defmodule PhoenixDatatables.QueryTest do
  use PhoenixDatatablesExample.DataCase
  alias PhoenixDatatables.Request
  alias PhoenixDatatables.Query
  alias PhoenixDatatables.Query.Attribute
  alias PhoenixDatatablesExample.Repo
  alias PhoenixDatatablesExample.Stock.Item
  alias PhoenixDatatablesExample.Stock.Category
  alias PhoenixDatatablesExample.Factory

  @sortable [:nsn, :common_name]

  describe "sort" do
    test "appends order-by clause to a single-table query specifying sortable fields" do
      [item1, item2] = add_items()
      assert item1.id != nil
      assert item2.id != nil
      assert item2.nsn < item1.nsn

      query =
        Factory.raw_request
        |> Request.receive
        |> Query.sort(Item, @sortable)

      [ritem2, ritem1] = query |> Repo.all
      assert item1.id == ritem1.id
      assert item2.id == ritem2.id
    end

    test "appends order-by clause to a single-table, single order_by queryable request" do
      [item1, item2] = add_items()
      assert item1.id != nil
      assert item2.id != nil
      assert item2.nsn < item1.nsn

      query =
        Factory.raw_request
        |> Request.receive
        |> Query.sort(Item)

      [ritem2, ritem1] = query |> Repo.all
      assert item1.id == ritem1.id
      assert item2.id == ritem2.id
    end

    test "appends order-by clause to a joined table" do
      [item1, item2] = add_items()

      request = %{Factory.raw_request | "order" => %{"0" => %{"column" => "7", "dir" => "asc"}}}
      query =
        (from item in Item,
          join: category in assoc(item, :category),
          select: %{id: item.id, category_name: category.name})

      query =
        request
        |> Request.receive
        |> Query.sort(query)

      [ritem2, ritem1] = query |> Repo.all
      assert item1.id == ritem1.id
      assert item2.id == ritem2.id

    end
  end

  describe "paginate" do
    test "appends appropriate paginate clauses to a single-table queryable request" do
      received_params = Factory.raw_request
      query = Query.paginate(Item, Request.receive(received_params))
      [{length, _}] = query.limit.params
      assert length == String.to_integer(received_params["length"])
      [{offset, _}] = query.offset.params
      assert offset == String.to_integer(received_params["start"])
    end
  end

  describe "attributes" do
    test "can find string attributes of a an Ecto schema" do
      %Attribute{name: name} = Attribute.extract("nsn", Item)
      assert name == :nsn
    end

    test "can find string attributes of a related schema" do
      %Attribute{name: name, parent: parent} = Attribute.extract("category_name", Item)
      assert name == :name
      assert parent == :category
    end
  end

  describe "join_order" do
    test "finds index of matching parent relation" do
      query =
      (from item in Item,
        join: category in assoc(item, :category),
        join: unit in assoc(item, :unit),
        select: %{id: item.id, category_name: category.name})
      assert Query.join_order(Item, :query) == 0
      assert Query.join_order(query, :category) == 1
      assert Query.join_order(query, :unit) == 2
    end
  end

  describe "total_entries" do
    test "returns the total number of entries in the table" do
      items = add_items()
      assert Query.total_entries(Item, Repo) == length(items)
    end
  end

  describe "search" do
    test "returns 1 result when 1 match found" do
      add_items()
      received_params = Factory.raw_request
      received_params = Map.put(
        received_params,
        "search",
        %{"regex" => "false", "value" => "167"}
      )
      Query.search(Item, Request.receive(received_params))
      |> Repo.all
      |> IO.inspect
    end
  end

  def add_items do
    category_a = insert_category!("A")
    category_b = insert_category!("B")
    item = Map.put(Factory.item, :category_id, category_b.id)
    item2 = Map.put(Factory.item, :category_id, category_a.id)
    item2 = %{item2 | nsn: "1NSN"}
    one = insert_item! item
    two = insert_item! item2
    [one, two]
  end

  def insert_item!(item) do
    cs = Item.changeset(%Item{}, item)
    Repo.insert!(cs)
  end

  def insert_category!(category) do
    cs = Category.changeset(%Category{}, %{name: category})
    Repo.insert!(cs)
  end
end
