defmodule HTMLParser.ParseStateTest do
  use ExUnit.Case
  alias HTMLParser.ParseState

  doctest ParseState

  describe "new/0" do
    test "returns struct" do
      assert ParseState.new() == %ParseState{}
    end
  end

  describe "build_open_tag/2" do
    test "adds characters to open tag" do
      parse_state = ParseState.new()
      assert parse_state.open_tag == ""
      parse_state = ParseState.build_open_tag(parse_state, <<"hi">>)
      assert parse_state.open_tag == "hi"
    end
  end

  describe "build_close_tag/2" do
    test "adds characters to close tag" do
      parse_state = ParseState.new()
      assert parse_state.close_tag == ""
      parse_state = ParseState.build_close_tag(parse_state, <<"bye">>)
      assert parse_state.close_tag == "bye"
    end
  end

  describe "build_text/2" do
    test "adds characters to text" do
      parse_state = ParseState.new()
      assert parse_state.text == ""
      parse_state = ParseState.build_text(parse_state, <<"yo">>)
      assert parse_state.text == "yo"
    end
  end

  describe "build_comment/2" do
    test "adds characters to comment" do
      parse_state = ParseState.new()
      assert parse_state.comment == ""
      parse_state = ParseState.build_comment(parse_state, <<"yo">>)
      assert parse_state.comment == "yo"
    end
  end

  describe "build_attr_key/2" do
    test "adds characters to attr_key" do
      parse_state = ParseState.new()
      assert parse_state.attr_key == ""
      parse_state = ParseState.build_attr_key(parse_state, <<"class">>)
      assert parse_state.attr_key == "class"
    end
  end

  describe "build_attr_value/2" do
    test "adds characters to attr_value" do
      parse_state = ParseState.new()
      assert parse_state.attr_value == ""
      parse_state = ParseState.build_attr_value(parse_state, <<"red">>)
      assert parse_state.attr_value == "red"
    end
  end

  describe "put_attr/1" do
    test "stores attr in attrs map and clears attr string" do
      parse_state = %ParseState{attr_key: "class", attr_value: "red"}
      parse_state = ParseState.put_attr(parse_state)
      assert parse_state.attr_key == ""
      assert parse_state.attr_value == ""
      assert parse_state.attrs == %{"class" => "red"}
    end

    test "works with bool attributes" do
      parse_state = %ParseState{attr_key: "disabled", attr_value: ""}
      parse_state = ParseState.put_attr(parse_state)
      assert parse_state.attr_key == ""
      assert parse_state.attr_value == ""
      assert parse_state.attrs == %{"disabled" => true}
    end
  end

  describe "add_text/1" do
    test "stores text in node list and clears text string" do
      parse_state = %ParseState{text: "yo"}
      parse_state = ParseState.add_text(parse_state)
      assert parse_state.text == ""
      assert parse_state.tags == [text: "yo"]
    end
  end

  describe "add_comment/1" do
    test "stores comment in node list and clears comment string" do
      parse_state = %ParseState{comment: "yo"}
      parse_state = ParseState.add_comment(parse_state)
      assert parse_state.comment == ""
      assert parse_state.tags == [comment: "yo"]
    end
  end

  describe "add_attrs/1" do
    test "merges attrs into meta, stores meta in last node and clears attrs" do
      parse_state = %ParseState{
        attrs: %{"id" => "1"},
        tags: [div: %{attrs: %{}, depth_count: 0, type: :open}]
      }

      parse_state = ParseState.add_attrs(parse_state)
      assert parse_state.attrs == %{}
      assert parse_state.tags == [div: %{attrs: %{"id" => "1"}, depth_count: 0, type: :open}]
    end
  end

  describe "add_open_tag/1" do
    test "stores open tag in node list with metadata and clears open tag string" do
      parse_state = %ParseState{open_tag: "div"}
      parse_state = ParseState.add_open_tag(parse_state)
      assert parse_state.open_tag == ""
      assert parse_state.tags == [div: %{attrs: %{}, depth_count: 0, type: :open}]
    end
  end

  describe "set_char_count/2" do
    test "adds value to char count" do
      parse_state = %ParseState{}
      assert parse_state.char_count == 0
      parse_state = ParseState.set_char_count(parse_state, 2)
      assert parse_state.char_count == 2
    end
  end

  describe "set_newline_count/2" do
    test "adds value to new line count" do
      parse_state = %ParseState{}
      assert parse_state.newline_count == 0
      parse_state = ParseState.set_newline_count(parse_state, 2)
      assert parse_state.newline_count == 2
    end
  end

  describe "add_meta/1" do
    test "produces meta map from other properties" do
      parse_state = ParseState.new()
      assert parse_state.meta == %{}

      assert ParseState.add_meta(parse_state).meta == %{
               attrs: %{},
               char_count: 0,
               newline_count: 0
             }
    end
  end

  describe "get_tags/1" do
    test "returns reversed list of tags" do
      parse_state =
        %ParseState{open_tag: "div", close_tag: "div"}
        |> ParseState.add_open_tag()
        |> ParseState.add_close_tag()

      tags = parse_state.tags
      assert ParseState.get_tags(parse_state) == Enum.reverse(tags)
    end
  end

  describe "add_close_tag/1" do
    test "stores close tag in node list with metadata and clears close tag string" do
      parse_state = %ParseState{open_tag: "div", close_tag: "div"}

      parse_state =
        parse_state
        |> ParseState.add_open_tag()
        |> ParseState.add_close_tag()

      parse_state = %ParseState{parse_state | open_tag: "div", close_tag: "div"}

      parse_state =
        parse_state
        |> ParseState.add_open_tag()
        |> ParseState.add_close_tag()

      assert parse_state.close_tag == ""

      assert parse_state.tags == [
               div: %{attrs: %{}, depth_count: 0, type: :close},
               div: %{attrs: %{}, depth_count: 0, type: :open},
               div: %{attrs: %{}, depth_count: 0, type: :close},
               div: %{attrs: %{}, depth_count: 0, type: :open}
             ]
    end
  end

  describe "put_attr_quote/2" do
    test "sets attr quote type" do
      parse_state = ParseState.new()
      assert parse_state.attr_quote == :double
      assert ParseState.put_attr_quote(parse_state, :single).attr_quote == :single
    end
  end
end
