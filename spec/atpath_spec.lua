describe("parse", function()
    local atpath = require 'atpath'
    local p = atpath.parse
    it("normal", function()
        assert.is.same(p("a"), {[1]="a", is_absolute=false})
        assert.is.same(p("a/b/c"), {[1]="a", [2]="b", [3]="c", is_absolute=false})
        assert.is.same(p("apple/banana/cherry"), {[1]="apple", [2]="banana", [3]="cherry", is_absolute=false})
        assert.is.same(p("/a"), {[1]="a", is_absolute=true})
        assert.is.same(p("/a/b/c"), {[1]="a", [2]="b", [3]="c", is_absolute=true})
        assert.is.same(p("/apple/banana/cherry"), {[1]="apple", [2]="banana", [3]="cherry", is_absolute=true})
    end)
    it("slashes", function()
        assert.is.same(p("/"), {is_absolute=true})
        assert.is.same(p("//"), {is_absolute=true})
        assert.is.same(p("a//"), {[1]="a", is_absolute=false})
        assert.is.same(p("//a"), {[1]="a", is_absolute=true})
        assert.is.same(p("/a/"), {[1]="a", is_absolute=true})
        assert.is.same(p("a//b"), {[1]="a", [2]="b", is_absolute=false})
        assert.is.same(p("a///b///c"), {[1]="a", [2]="b", [3]="c", is_absolute=false})
    end)
    it("dot_and_double_dot", function()
        assert.is.same(p("./a/b"), {[1]="a", [2]="b", is_absolute=false})
        assert.is.same(p("a/./b"), {[1]="a", [2]="b", is_absolute=false})
        assert.is.same(p("a/b/."), {[1]="a", [2]="b", is_absolute=false})
        assert.is.same(p("a/././b"), {[1]="a", [2]="b", is_absolute=false})
        assert.is.same(p("a/./b/./c"), {[1]="a", [2]="b", [3]="c", is_absolute=false})
        assert.is.same(p("././."), {is_absolute=false})
        assert.is.same(p("a/b/c/../d"), {[1]="a", [2]="b", [3]="d", is_absolute=false})
        assert.is.same(p("a/b/../../d"), {[1]="d", is_absolute=false})
        assert.is.same(p("a/../b/../c"), {[1]="c", is_absolute=false})
        assert.has.errors(function() p("..") end)
        assert.has.errors(function() p("../..") end)
        assert.has.errors(function() p("../a") end)
        assert.is.same(p("a/.."), {is_absolute=false})
        assert.has.errors(function() p("a/../..") end)
        assert.has.errors(function() p("a/b/c/../../../..") end)
    end)
    it("auto_convert_to_number", function()
        atpath.options.auto_convert_to_number = true
        assert.is.same(p("1/2/3"), {[1]=1, [2]=2, [3]=3, is_absolute=false})
        assert.is.same(p("0x7F/-1.5/2e+3/4e-5"), {[1]=127, [2]=-1.5, [3]=2000, [4]=0.00004, is_absolute=false})
        assert.is.same(p([[1/'2'/"3"]]), {[1]=1, [2]="2", [3]="3", is_absolute=false})
        atpath.options.auto_convert_to_number = false
        assert.is.same(p("1/2/3"), {[1]="1", [2]="2", [3]="3", is_absolute=false})
        assert.is.same(p("0x7F/-1.5/2e+3/4e-5"), {[1]="0x7F", [2]="-1.5", [3]="2e+3", [4]="4e-5", is_absolute=false})
        assert.is.same(p([[1/'2'/"3"]]), {[1]="1", [2]="2", [3]="3", is_absolute=false})
    end)
    it("auto_convert_to_boolean", function()
        atpath.options.auto_convert_to_boolean = true
        assert.is.same(p("true/false"), {[1]=true, [2]=false, is_absolute=false})
        assert.is.same(p([[true/'true'/"false"]]), {[1]=true, [2]="true", [3]="false", is_absolute=false})
        atpath.options.auto_convert_to_boolean = false
        assert.is.same(p("true/false"), {[1]="true", [2]="false", is_absolute=false})
        assert.is.same(p([[true/'true'/"false"]]), {[1]="true", [2]="true", [3]="false", is_absolute=false})
    end)
    it("de-escape", function()
        assert.is.same(p(
            "%E4%B8%AD%E6%96%87/"
            .. "%E3%81%AB%E3%81%BB%E3%82%93%E3%81%94/"
            .. "%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9"
        ), {
            [1] = "中文",
            [2] = "にほんご",
            [3] = "Русский",
            is_absolute = false
        })
        assert.is.same(p("%25%2F%27%22"), {[1]=[[%/'"]], is_absolute=false})
    end)
end)

describe("build", function()
    local atpath = require 'atpath'
    local b = atpath.build
    it("normal", function()
        assert.is.same(b({"a"}), "a")
        assert.is.same(b({"a", "b", "c"}), "a/b/c")
        assert.is.same(b({"apple", "banana", "cherry"}), "apple/banana/cherry")
        assert.is.same(b({"apple", "banana", "cherry"}, "module"), "/module/apple/banana/cherry")
        assert.is.same(b({"apple", "banana", "cherry"}, "module.inner"), "/module.inner/apple/banana/cherry")
        assert.has.error(function() b({"a", {"invalid"}, "c"}) end)
    end)
    it("ranges", function()
        local series = {"a", "b", "c", "d", "e"}
        assert.is.same(b(series, nil, 6, 3), "")
        assert.is.same(b(series, nil, 4, 3), "")
        assert.is.same(b(series, nil, 3, 3), "c")
        assert.is.same(b(series, nil, 2, 3), "b/c")
        assert.is.same(b(series, nil, 1, 3), "a/b/c")
        assert.is.same(b(series, nil, 0, 3), "a/b/c")
        assert.is.same(b(series, nil, -1, 3), "")
        assert.is.same(b(series, nil, -3, 3), "c")
        assert.is.same(b(series, nil, -4, 3), "b/c")
        assert.is.same(b(series, nil, -5, 3), "a/b/c")
        assert.is.same(b(series, nil, -6, 3), "a/b/c")
        assert.is.same(b(series, nil, 3, 6), "c/d/e")
        assert.is.same(b(series, nil, 3, 5), "c/d/e")
        assert.is.same(b(series, nil, 3, 4), "c/d")
        assert.is.same(b(series, nil, 3, 3), "c")
        assert.is.same(b(series, nil, 3, 2), "")
        assert.is.same(b(series, nil, 3, 0), "")
        assert.is.same(b(series, nil, 3, -1), "c/d/e")
        assert.is.same(b(series, nil, 3, -2), "c/d")
        assert.is.same(b(series, nil, 3, -3), "c")
        assert.is.same(b(series, nil, 3, -4), "")
        assert.is.same(b(series, nil, 3, -6), "")
        assert.is.same(b(series, "module", 3, 3), "/module/c")
        assert.is.same(b(series, "module", 6, 3), "/module")
    end)
    it("literal", function()
        assert.is.same(b({"1", 2, "true", false, 0x7F}), [['1'/2/'true'/false/127]])
    end)
    it("escape", function()
        assert.is.same(b({"%", "/", [[']], [["]]}), "%25/%2F/%27/%22")
        assert.is.same(b({".", ".."}), "%2e/%2e%2e")
        assert.is.same(
            b({"中文", "にほんご", "Русский"}),
            "%E4%B8%AD%E6%96%87/"
            .."%E3%81%AB%E3%81%BB%E3%82%93%E3%81%94/"
            .."%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9"
        )
    end)
end)

describe("at", function()
    local atpath = require 'atpath'
    atpath.options.auto_convert_to_number = true
    atpath.options.auto_convert_to_boolean = true
    local t = {
        [1] = "first",
        [2] = "second",
        ["1"] = "literalone",
        [true] = true,
        inner = {
            we = "ours",
            you = "yours",
        }
    }
    local a = atpath.at
    assert.is.same(a(t, ""), t)
    assert.is.same(a(t, "1"), "first")
    assert.is.same(a(t, "0x02"), "second")
    assert.is.same(a(t, [['1']]), "literalone")
    assert.is.same(a(t, [["1"]]), "literalone")
    assert.is.same(a(t, "true"), true)
    assert.is.same(a(t, "inner"), {we="ours", you="yours"})
    assert.is.same(a(t, "inner/we"), "ours")
    assert.is.same(a(t, "nonexistant"), nil)
    assert.is.same(a(t, "inner/nonexistant"), nil)
    assert.has.errors(function() a(t, "/") end)
    assert.has.errors(function() a(t, "/1") end)
    assert.has.errors(function() a(t, "nonexistant/another") end)
end)

insulate("mob_require", function()
    local atpath = require 'atpath'
    local mob_module_busted = {
        describe = describe,
        it = it,
        assert = assert
    }
    local mob_module_testmodule = {
        hi = "hi",
        profile = {
            one = 1,
            two = "2",
        }
    }
    local mob_require = function(modulename)
        if modulename == "busted" then return mob_module_busted
        elseif modulename == "testmodule" then return mob_module_testmodule
        else error("Module not found!") end
    end
    atpath.options.require = mob_require

    describe("at_module", function()
        assert.is.same(atpath.options.require, mob_require)
        local am = atpath.at_module
        assert.is.same(am("/busted/describe"), describe)
        assert.is.same(am("/busted/assert/is"), assert.is)
        assert.is.same(am("/testmodule/hi"), "hi")
        assert.is.same(am("/testmodule/profile/one"), 1)
        assert.is.same(am("/testmodule/profile/fifteen"), nil)
        assert.has.errors(function() am("relative") end)
        assert.has.errors(function() am("relative/inner") end)
        assert.has.errors(function() am("/nonexistantmodule") end)
        assert.has.errors(function() am("/nonexistantmodule/inner") end)
        assert.has.errors(function() am("/") end)
    end)

end)
