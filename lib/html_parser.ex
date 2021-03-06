defmodule HTMLParser do
  @moduledoc """
  Parses an HTML string and returns an Elixir representation

  ## Examples

    iex> html = "<div><p>yo</p><input disabled></div>"
    iex> {:ok, %HTMLParser.HTMLNodeTree{tag: :div}} = HTMLParser.parse(html)
  """

  alias HTMLParser.{HTMLNodeTree, ParseState, TreeBuilder}

  @type html :: String.t()

  @spec parse(html) :: {:ok, HTMLNodeTree.t() | [HTMLNodeTree.t()]} | {:error, any()}

  @doc """
  Parses an HTML string and returns an Elixir representation of HTML nodes with `HTMLNodeTree`
  """
  def parse(html) when is_binary(html) do
    parse_state = ParseState.new()

    parse_state
    |> do_parse(html, :init)
    |> ParseState.get_tags()
    |> TreeBuilder.build()
  end

  # Comment parsing
  defp do_parse(parse_state, <<"<!--">> <> rest, _state) do
    parse_state
    |> ParseState.set_char_count(4)
    |> do_parse(rest, :parse_comment)
  end

  defp do_parse(parse_state, <<"-->">> <> rest, :parse_comment) do
    parse_state
    |> ParseState.set_char_count(3)
    |> ParseState.add_comment()
    |> do_parse(rest, :continue)
  end

  defp do_parse(parse_state, <<comment>> <> rest, :parse_comment) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_comment(<<comment>>)
    |> do_parse(rest, :parse_comment)
  end

  # Parse started - wait until open tag
  defp do_parse(parse_state, <<"<">> <> rest, :init) do
    parse_state
    |> ParseState.set_char_count()
    |> do_parse(rest, :parse_open_tag)
  end

  defp do_parse(parse_state, <<_>> <> rest, :init) do
    parse_state
    |> ParseState.set_char_count()
    |> do_parse(rest, :init)
  end

  # End of open tag
  defp do_parse(parse_state, <<">">> <> rest, :parse_open_tag) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.add_open_tag()
    |> ParseState.add_attrs()
    |> do_parse(rest, :continue)
  end

  # Start parsing attributes
  defp do_parse(parse_state, <<" ">> <> rest, :parse_open_tag) do
    parse_state
    |> ParseState.set_char_count()
    |> do_parse(rest, :parse_attrs)
  end

  # Build open tag
  defp do_parse(parse_state, <<open_tag>> <> rest, :parse_open_tag) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_open_tag(<<open_tag>>)
    |> do_parse(rest, :parse_open_tag)
  end

  # Attr parsing done
  defp do_parse(parse_state, <<"/", ">">> <> rest, :parse_attrs) do
    parse_state
    |> ParseState.set_char_count()
    |> do_parse(<<">">> <> rest, :parse_open_tag)
  end

  defp do_parse(parse_state, <<">">> <> rest, :parse_attrs) do
    parse_state
    |> do_parse(<<">">> <> rest, :parse_open_tag)
  end

  # Ignore spaces until we find the key
  defp do_parse(parse_state, " " <> rest, :parse_attrs) do
    parse_state
    |> ParseState.set_char_count()
    |> do_parse(rest, :parse_attrs)
  end

  defp do_parse(parse_state, rest, :parse_attrs) do
    parse_state
    |> do_parse(rest, :build_attr_key)
  end

  # Handle single and double quotes
  # If we encounter a quote while parsing a value, end parsing
  # if it's same type, add it otherwise
  defp do_parse(parse_state, <<"\"">> <> rest, :build_attr_value) do
    if ParseState.get_attr_quote(parse_state) == :double do
      parse_state
      |> ParseState.set_char_count()
      |> ParseState.put_attr()
      |> do_parse(rest, :parse_attrs)
    else
      parse_state
      |> ParseState.set_char_count()
      |> ParseState.build_attr_value(<<"\"">>)
      |> do_parse(rest, :build_attr_value)
    end
  end

  defp do_parse(parse_state, <<"\'">> <> rest, :build_attr_value) do
    if ParseState.get_attr_quote(parse_state) == :single do
      parse_state
      |> ParseState.set_char_count()
      |> ParseState.put_attr()
      |> do_parse(rest, :parse_attrs)
    else
      parse_state
      |> ParseState.set_char_count()
      |> ParseState.build_attr_value(<<"\'">>)
      |> do_parse(rest, :build_attr_value)
    end
  end

  # End of attribute key and start of value
  defp do_parse(parse_state, <<"=\"">> <> rest, :build_attr_key) do
    parse_state
    |> ParseState.set_char_count(2)
    |> ParseState.put_attr_quote(:double)
    |> do_parse(rest, :build_attr_value)
  end

  defp do_parse(parse_state, <<"=\'">> <> rest, :build_attr_key) do
    parse_state
    |> ParseState.set_char_count(2)
    |> ParseState.put_attr_quote(:single)
    |> do_parse(rest, :build_attr_value)
  end

  # No attribute value: key is self-standing (has true value)
  defp do_parse(parse_state, <<" ">> <> rest, :build_attr_key) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.put_attr()
    |> do_parse(rest, :parse_attrs)
  end

  defp do_parse(parse_state, <<">">> <> rest, :build_attr_key) do
    parse_state
    |> ParseState.put_attr()
    |> do_parse(<<">">> <> rest, :parse_attrs)
  end

  # Build attribute key / values
  defp do_parse(parse_state, <<attr_key>> <> rest, :build_attr_key) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_attr_key(<<attr_key>>)
    |> do_parse(rest, :build_attr_key)
  end

  defp do_parse(parse_state, <<attr_value>> <> rest, :build_attr_value) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_attr_value(<<attr_value>>)
    |> do_parse(rest, :build_attr_value)
  end

  # Text parsing finished - close tag encountered
  defp do_parse(parse_state, <<"<", "/">> <> rest, :parse_text) do
    parse_state
    |> ParseState.set_char_count(2)
    |> ParseState.add_text()
    |> do_parse(rest, :parse_close_tag)
  end

  # Tag found as sibling to text
  defp do_parse(parse_state, <<"<">> <> rest, :parse_text) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.add_text()
    |> do_parse(rest, :parse_open_tag)
  end

  # Build text
  defp do_parse(parse_state, <<text>> <> rest, :parse_text) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_text(<<text>>)
    |> do_parse(rest, :parse_text)
  end

  # Start of closing tag
  defp do_parse(parse_state, <<"<", "/">> <> rest, :parse_open_tag) do
    parse_state
    |> ParseState.set_char_count(2)
    |> ParseState.add_meta()
    |> do_parse(rest, :parse_close_tag)
  end

  defp do_parse(parse_state, <<"<", "/">> <> rest, :continue) do
    parse_state
    |> ParseState.set_char_count(2)
    |> ParseState.add_meta()
    |> do_parse(rest, :parse_close_tag)
  end

  # End of closing tag
  defp do_parse(parse_state, <<">">> <> rest, :parse_close_tag) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.add_close_tag()
    |> do_parse(rest, :continue)
  end

  # Build closing tag
  defp do_parse(parse_state, <<close_tag>> <> rest, :parse_close_tag) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_close_tag(<<close_tag>>)
    |> do_parse(rest, :parse_close_tag)
  end

  # Start parsing open tag
  defp do_parse(parse_state, <<"<">> <> rest, :continue) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.add_meta()
    |> do_parse(rest, :parse_open_tag)
  end

  # Ignore newline characters
  defp do_parse(parse_state, <<"\n">> <> rest, :continue) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.set_newline_count()
    |> do_parse(rest, :continue)
  end

  # Parse text
  defp do_parse(parse_state, <<text>> <> rest, :continue) do
    parse_state
    |> ParseState.set_char_count()
    |> ParseState.build_text(<<text>>)
    |> do_parse(rest, :parse_text)
  end

  # End of parse
  defp do_parse(parse_state, "", _state) do
    parse_state
  end
end
