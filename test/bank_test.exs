defmodule BankTest do
  use ExUnit.Case
  doctest Bank

  describe "opening accounts" do
    setup do
      [r: Bank.open_account()]
    end

    test "it works", %{r: r} do
      assert {:ok, _} = r
    end
  end

  describe "basic balance" do
    @describetag :skip
    setup do
      [r: Bank.open_account()]
    end

    test "accounts start with 0 balance", %{r: r} do
      {:ok, id} = r
      wait_until(fn ->
        assert {:ok, 0} = Bank.get_balance(id)
      end)
    end

    test "we can't get the balance for unexistent accounts" do
      assert {:error, :not_found} = Bank.get_balance(UUID.uuid4)
    end
  end

  describe "adding funds" do
    @describetag :skip
    setup do
      {:ok, account_id} = Bank.open_account()
      [id: account_id, r: Bank.add_funds(account_id, 100)]
    end

    test "it works", %{r: r} do
      assert :ok = r
    end

    test "we cant add funds to inexistent accounts" do
      assert {:error, :not_found} = Bank.add_funds(UUID.uuid4, 100)
    end

    test "it increases the balance", %{id: id} do
      wait_until(fn ->
        assert {:ok, 100} = Bank.get_balance(id)
      end)
    end
  end

  describe "removing funds" do
    @describetag :skip
    setup do
      {:ok, account_id} = Bank.open_account()
      :ok = Bank.add_funds(account_id, 100)
      [id: account_id, r: Bank.remove_funds(account_id, 10)]
    end

    test "it works", %{r: r} do
      assert :ok = r
    end

    test "it decreases the balance", %{id: id} do
      wait_until(fn ->
        assert {:ok, 90} = Bank.get_balance(id)
      end)
    end

    test "it decreases the balance on the write side" do
      {:ok, account_id} = Bank.open_account()
      :ok = Bank.add_funds(account_id, 100)
      :ok = Bank.remove_funds(account_id, 100)
      response = Bank.remove_funds(account_id, 100)
      assert {:error, :insufficient_funds} = response
    end

    test "we cant remove funds to inexistent accounts" do
      assert {:error, :not_found} = Bank.remove_funds(UUID.uuid4, 100)
    end

    test "we cant remove funds without money", %{id: id} do
      resp = Bank.remove_funds(id, 10000)
      assert {:error, :insufficient_funds} = resp
    end
  end

  describe "transfering money" do
    @describetag :skip
    setup do
      {:ok, source_id} = Bank.open_account()
      {:ok, target_id} = Bank.open_account()
      :ok = Bank.add_funds(source_id, 100)
      r = Bank.transfer(source_id, target_id, 10)
      [source_id: source_id, target_id: target_id, r: r]
    end

    test "it works", %{r: r} do
      assert :ok = r
    end

    test "it decreases the source balance", %{source_id: id} do
      wait_until(fn ->
        assert {:ok, 90} = Bank.get_balance(id)
      end)
    end

    test "it increases the target balance", %{target_id: id} do
      wait_until(fn ->
        assert {:ok, 10} = Bank.get_balance(id)
      end)
    end

    test "we cant transfer without money", ctx do
      resp = Bank.transfer(ctx[:source_id], ctx[:target_id], 10000)
      assert {:error, :insufficient_funds} = resp
    end
  end

  describe "statement" do
    @describetag :skip
    setup do
      {:ok, account_id} = Bank.open_account()
      {:ok, empty_account_id} = Bank.open_account()
      :ok = Bank.add_funds(account_id, 100)
      :ok = Bank.remove_funds(account_id, 100)
      [account_id: account_id, empty_account_id: empty_account_id]
    end

    test "we can get the statement", ctx do
      wait_until(fn ->
        {:ok, account_txs} = Bank.get_statement(ctx[:account_id])
        {:ok, empty_account_txs} = Bank.get_statement(ctx[:empty_account_id])
        assert [_, _] = account_txs
        assert [
          %{amount: 100},
          %{amount: -100}
        ] = account_txs
        assert [] = empty_account_txs
      end)
    end

    test "we can't get the statement for unexistent accounts" do
      assert {:error, :not_found} = Bank.get_statement(UUID.uuid4)
    end
  end

  # Async test helper
  defp wait_until(fun), do: wait_until(400, fun)
  defp wait_until(t, fun) when t <= 0, do: fun.()
  defp wait_until(timeout, fun) do
    fun.()
  rescue
    _ ->
      :timer.sleep(10)
    wait_until(max(0, timeout - 10), fun)
  end
end
