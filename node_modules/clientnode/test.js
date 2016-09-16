// @flow
// #!/usr/bin/env node
// -*- coding: utf-8 -*-
'use strict'
/* !
    region header
    Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

    License
    -------

    This library written by Torben Sickert stand under a creative commons
    naming 3.0 unported license.
    See http://creativecommons.org/licenses/by/3.0/deed.de
    endregion
*/
// region imports
import browserAPI from 'weboptimizer/browserAPI'
import type {BrowserAPI} from 'weboptimizer/type'
import type {$DomNode} from './index'
// endregion
// region types
export type Test = {
    callback:Function;
    closeWindow:boolean;
    roundTypes:Array<string>
}
// endregion
// region declaration
declare var TARGET_TECHNOLOGY:string
// endregion
// region determine technology specific qunit implementation
let QUnit:Object
if (typeof TARGET_TECHNOLOGY === 'undefined' || TARGET_TECHNOLOGY === 'node')
    QUnit = require('qunit-cli')
else
    QUnit = require('script!qunitjs') && window.QUnit
// endregion
// region default test specification
let tests:Array<Test> = [{callback: function(
    roundType:string, targetTechnology:?string, $:any, browserAPI:BrowserAPI,
    tools:Object, $bodyDomNode:$DomNode
):void {
    this.module(`tools (${roundType})`)
    // region tests
    // / region public methods
    // // region special
    this.test(`constructor (${roundType})`, (assert:Object):void =>
        assert.ok(tools))
    this.test(`destructor (${roundType})`, (assert:Object):void =>
        assert.strictEqual(tools.destructor(), tools))
    this.test(`initialize (${roundType})`, (assert:Object):void => {
        const secondToolsInstance = $.Tools({logging: true})
        const thirdToolsInstance = $.Tools({
            domNodeSelectorPrefix: 'body.{1} div.{1}'})

        assert.notOk(tools._options.logging)
        assert.ok(secondToolsInstance._options.logging)
        assert.strictEqual(
            thirdToolsInstance._options.domNodeSelectorPrefix,
            'body.tools div.tools')
    })
    // // endregion
    // // region object orientation
    this.test(`controller (${roundType})`, (assert:Object):void => {
        assert.strictEqual(tools.controller(tools, []), tools)
        assert.strictEqual(tools.controller(
            $.Tools.class, [], $('body')
        ).constructor.name, tools.constructor.name)
    })
    // // endregion
    // // region mutual exclusion
    this.test(`acquireLock|releaseLock (${roundType})`, (
        assert:Object
    ):void => {
        let testValue = false
        tools.acquireLock('test', ():void => {
            testValue = true
        })

        assert.ok(testValue)
        assert.strictEqual(tools.acquireLock('test', ():void => {
            testValue = false
        }, true), tools)
        assert.ok(testValue)
        assert.ok($.Tools().releaseLock('test'))
        assert.ok(testValue)
        assert.strictEqual(tools.releaseLock('test'), tools)
        assert.notOk(testValue)
        assert.strictEqual(tools.acquireLock('test', ():void => {
            testValue = true
        }, true), tools)
        assert.ok(testValue)
        assert.strictEqual(tools.acquireLock('test', ():void => {
            testValue = false
        }), tools)
        assert.notOk(testValue)
    })
    // // endregion
    // // region boolean
    this.test(`isNumeric (${roundType})`, (assert:Object):void => {
        for (const test:any of [
            0,
            1,
            '-10',
            '0',
            0xFF,
            '0xFF',
            '8e5',
            '3.1415',
            +10
        ])
            assert.ok($.Tools.class.isNumeric(test))
        for (const test:any of [
            null,
            undefined,
            false,
            true,
            '',
            'a',
            {},
            /a/,
            '-0x42',
            '7.2acdgs',
            NaN,
            Infinity
        ])
            assert.notOk($.Tools.class.isNumeric(test))
    })
    this.test(`isWindow (${roundType})`, (assert:Object):void => {
        assert.ok($.Tools.class.isWindow(browserAPI.window))
        for (const test:any of [
            null,
            {},
            browserAPI
        ])
            assert.notOk($.Tools.class.isWindow(test))
    })
    this.test(`isArrayLike (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [], window.document.querySelectorAll('*')
        ])
            assert.ok($.Tools.class.isArrayLike(test))
        for (const test:any of [
            {},
            null,
            undefined,
            false,
            true,
            /a/
        ])
            assert.notOk($.Tools.class.isArrayLike(test))
    })
    this.test(`isAnyMatching (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            ['', ['']],
            ['test', [/test/]],
            ['test', [/a/, /b/, /es/]],
            ['test', ['', 'test']]
        ])
            assert.ok($.Tools.class.isAnyMatching.apply($.Tools, test))
        for (const test:Array<any> of [
            ['', []],
            ['test', [/tes$/]],
            ['test', [/^est/]],
            ['test', [/^est$/]],
            ['test', ['a']]
        ])
            assert.notOk($.Tools.class.isAnyMatching.apply($.Tools, test))
    })
    this.test(`isPlainObject (${roundType})`, (assert:Object):void => {
        for (const okValue:any of [
            {},
            {a: 1},
            /* eslint-disable no-new-object */
            new Object()
            /* eslint-enable no-new-object */
        ])
            assert.ok($.Tools.class.isPlainObject(okValue))
        for (const notOkValue:any of [
            new String(), Object, null, 0, 1, true, undefined
        ])
            assert.notOk($.Tools.class.isPlainObject(notOkValue))
    })
    this.test(`isFunction (${roundType})`, (assert:Object):void => {
        for (const okValue:any of [
            Object, new Function('return 1'), function():void {},
            ():void => {}
        ])
            assert.ok($.Tools.class.isFunction(okValue))
        for (const notOkValue:any of [
            null, false, 0, 1, undefined, {}, new Boolean()
        ])
            assert.notOk($.Tools.class.isFunction(notOkValue))
    })
    // // endregion
    // // region language fixes
    this.test(`mouseOutEventHandlerFix (${roundType})`, (
        assert:Object
    ):void => assert.ok($.Tools.class.mouseOutEventHandlerFix(
        ():void => {})))
    // // endregion
    // // region logging
    this.test(`log (${roundType})`, (assert:Object):void =>
        assert.strictEqual(tools.log('test'), tools))
    this.test(`info (${roundType})`, (assert:Object):void =>
        assert.strictEqual(tools.info('test {0}'), tools))
    this.test(`debug (${roundType})`, (assert:Object):void =>
        assert.strictEqual(tools.debug('test'), tools))
    // NOTE: This test breaks javaScript modules in strict mode.
    this.skip(`${roundType}-error`, (assert:Object):void =>
        assert.strictEqual(tools.error(
            'ignore this error, it is only a {1}', 'test'
        ), tools))
    this.test(`warn (${roundType})`, (assert:Object):void =>
        assert.strictEqual(tools.warn('test'), tools))
    this.test(`show (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [1, '1 (Type: "number")'],
            [null, 'null (Type: "null")'],
            [/a/, '/a/ (Type: "regexp")'],
            ['hans', 'hans (Type: "string")'],
            [
                {A: 'a', B: 'b'},
                'A: a (Type: "string")\nB: b (Type: "string")'
            ]
        ])
            assert.strictEqual($.Tools.class.show(test[0]), test[1])
        assert.ok((new RegExp(
            /* eslint-disable no-control-regex */
            '^(.|\n|\r|\u2028|\u2029)+\\(Type: "function"\\)$'
        )).test($.Tools.class.show($.Tools)))
        /* eslint-enable no-control-regex */
    })
    // // endregion
    // // region dom node handling
    if (roundType === 'withJQuery') {
        this.test(`getText (${roundType})`, (assert:Object):void => {
            for (const test:Array<string> of [
                ['<div>', ''],
                ['<div>hans</div>', 'hans'],
                ['<div><div>hans</div</div>', ''],
                ['<div>hans<div>peter</div></div>', 'hans']
            ])
                assert.strictEqual($(test[0]).Tools('getText'), test[1])
        })
        this.test(`normalizeClassNames (${roundType})`, (
            assert:Object
        ):void => {
            assert.strictEqual($('<div>').Tools(
                'normalizeClassNames'
            ).$domNode.prop('outerHTML'), $('<div>').prop('outerHTML'))
            assert.strictEqual($('<div class>').Tools(
                'normalizeClassNames'
            ).$domNode.html(), $('<div>').html())
            assert.strictEqual($('<div class="">').Tools(
                'normalizeClassNames'
            ).$domNode.html(), $('<div>').html())
            assert.strictEqual($('<div class="a">').Tools(
                'normalizeClassNames'
            ).$domNode.prop('outerHTML'), $('<div class="a">').prop(
                'outerHTML'))
            assert.strictEqual($('<div class="b a">').Tools(
                'normalizeClassNames'
            ).$domNode.prop('outerHTML'), $('<div class="a b">').prop(
                'outerHTML'))
            assert.strictEqual($(
                '<div class="b a"><pre class="c b a"></pre></div>'
            ).Tools('normalizeClassNames').$domNode.prop('outerHTML'),
            $('<div class="a b"><pre class="a b c"></pre></div>').prop(
                'outerHTML'))
        })
        this.test(`normalizeStyles (${roundType})`, (
            assert:Object
        ):void => {
            assert.strictEqual($('<div>').Tools(
                'normalizeStyles'
            ).$domNode.prop('outerHTML'), $('<div>').prop('outerHTML'))
            assert.strictEqual($('<div style>').Tools(
                'normalizeStyles'
            ).$domNode.html(), $('<div>').html())
            assert.strictEqual($('<div style="">').Tools(
                'normalizeStyles'
            ).$domNode.html(), $('<div>').html())
            assert.strictEqual($(
                '<div style="border: 1px solid  red ;">'
            ).Tools('normalizeStyles').$domNode.prop('outerHTML'), $(
                '<div style="border:1px solid red">'
            ).prop('outerHTML'))
            assert.strictEqual($(
                '<div style="width: 50px;height: 100px;">'
            ).Tools('normalizeStyles').$domNode.prop('outerHTML'), $(
                '<div style="height:100px;width:50px">'
            ).prop('outerHTML'))
            assert.strictEqual($(
                '<div style=";width: 50px ; height:100px">'
            ).Tools('normalizeStyles').$domNode.prop('outerHTML'), $(
                '<div style="height:100px;width:50px">'
            ).prop('outerHTML'))
            assert.strictEqual($(
                '<div style="width:10px;height:50px">' +
                '    <pre style=";;width:2px;height:1px; color: red; ">' +
                    '</pre>' +
                '</div>'
            ).Tools('normalizeStyles').$domNode.prop('outerHTML'),
            $(
                '<div style="height:50px;width:10px">' +
                '    <pre style="color:red;height:1px;width:2px"></pre>' +
                '</div>'
            ).prop('outerHTML'))
        })
        this.test(`isEquivalentDom (${roundType})`, (
            assert:Object
        ):void => {
            for (const test:Array<any> of [
                ['test', 'test'],
                ['test test', 'test test'],
                ['<div>', '<div>'],
                ['<div class>', '<div>'],
                ['<div class="">', '<div>'],
                ['<div style>', '<div>'],
                ['<div style="">', '<div>'],
                ['<div></div>', '<div>'],
                ['<div class="a"></div>', '<div class="a"></div>'],
                [
                    $('<a target="_blank" class="a"></a>'),
                    '<a class="a" target="_blank"></a>'
                ],
                [
                    '<a target="_blank" class="a"></a>',
                    '<a class="a" target="_blank"></a>'
                ],
                [
                    '<a target="_blank" class="a"><div b="3" a="2">' +
                    '</div></a>',
                    '<a class="a" target="_blank"><div a="2" b="3">' +
                    '</div></a>'
                ],
                [
                    '<a target="_blank" class="b a">' +
                    '   <div b="3" a="2"></div>' +
                    '</a>',
                    '<a class="a b" target="_blank">' +
                    '   <div a="2" b="3"></div>' +
                    '</a>'
                ],
                ['<div>a</div><div>b</div>', '<div>a</div><div>b</div>'],
                ['<div>a</div>b', '<div>a</div>b'],
                ['<br>', '<br />'],
                ['<div><br><br /></div>', '<div><br /><br /></div>'],
                [
                    ' <div style="">' +
                    'german<!--deDE--><!--enUS: english --> ' +
                    '</div>',
                    ' <div style="">' +
                    'german<!--deDE--><!--enUS: english --> ' +
                    '</div>'
                ],
                ['a<br>', 'a<br />', true]
            ])
                assert.ok($.Tools.class.isEquivalentDom.apply(this, test))
            for (const test:Array<any> of [
                ['test', ''],
                ['test', 'hans'],
                ['test test', 'testtest'],
                ['test test:', ''],
                ['<div class="a"></div>', '<div>'],
                [
                    $('<a class="a"></a>'),
                    '<a class="a" target="_blank"></a>'
                ],
                [
                    '<a target="_blank" class="a"><div a="2"></div></a>',
                    '<a class="a" target="_blank"></a>'
                ],
                ['<div>a</div>b', '<div>a</div>c'],
                [' <div>a</div>', '<div>a</div>'],
                ['<div>a</div><div>bc</div>', '<div>a</div><div>b</div>'],
                ['text', 'text a'],
                ['text', 'text a'],
                ['text', 'text a & +']
            ])
                assert.notOk(
                    $.Tools.class.isEquivalentDom.apply(this, test))
        })
    }
    if (roundType === 'withJQuery')
        this.test(`getPositionRelativeToViewport (${roundType})`, (
            assert:Object
        ):void => assert.ok([
            'above', 'left', 'right', 'below', 'in'
        ].includes(tools.getPositionRelativeToViewport())))
    this.test(`generateDirectiveSelector (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<string> of [
            [
                'a-b', 'a-b, .a-b, [a-b], [data-a-b], [x-a-b], [a\\:b], ' +
                '[a_b]'
            ],
            [
                'aB', 'a-b, .a-b, [a-b], [data-a-b], [x-a-b], [a\\:b], ' +
                '[a_b]'
            ],
            ['a', 'a, .a, [a], [data-a], [x-a]'],
            ['aa', 'aa, .aa, [aa], [data-aa], [x-aa]'],
            [
                'aaBB',
                'aa-bb, .aa-bb, [aa-bb], [data-aa-bb], [x-aa-bb], ' +
                    '[aa\\:bb], [aa_bb]'
            ],
            [
                'aaBbCcDd',
                'aa-bb-cc-dd, .aa-bb-cc-dd, [aa-bb-cc-dd], ' +
                '[data-aa-bb-cc-dd], [x-aa-bb-cc-dd], ' +
                '[aa\\:bb\\:cc\\:dd], [aa_bb_cc_dd]'
            ],
            [
                'mceHREF',
                'mce-href, .mce-href, [mce-href], [data-mce-href], ' +
                '[x-mce-href], [mce\\:href], [mce_href]'
            ]
        ])
            assert.strictEqual($.Tools.class.generateDirectiveSelector(
                test[0]
            ), test[1])
    })
    if (roundType === 'withJQuery')
        this.test(`removeDirective (${roundType})`, (
            assert:Object
        ):void => {
            const $localBodyDomNode = $bodyDomNode.Tools(
                'removeDirective', 'a')
            assert.equal($localBodyDomNode.Tools().removeDirective(
                'a'
            ), $localBodyDomNode)
        })
    this.test(`getNormalizedDirectiveName (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<string> of [
            ['data-a', 'a'],
            ['x-a', 'a'],
            ['data-a-bb', 'aBb'],
            ['x:a:b', 'aB']
        ])
            assert.equal(
                $.Tools.class.getNormalizedDirectiveName(test[0]), test[1])
    })
    if (roundType === 'withJQuery')
        this.test(`getDirectiveValue (${roundType})`, (
            assert:Object
        ):void => assert.equal(
            $('body').Tools('getDirectiveValue', 'a'), null))
    this.test(`sliceDomNodeSelectorPrefix (${roundType})`, (
        assert:Object
    ):void => {
        assert.strictEqual(
            tools.sliceDomNodeSelectorPrefix('body div'), 'div')
        assert.strictEqual($.Tools({
            domNodeSelectorPrefix: 'body div'
        }).sliceDomNodeSelectorPrefix('body div'), '')
        assert.strictEqual($.Tools({
            domNodeSelectorPrefix: ''
        }).sliceDomNodeSelectorPrefix('body div'), 'body div')
    })
    this.test(`getDomNodeName (${roundType})`, (assert:Object):void => {
        for (const test:Array<string> of [
            ['div', 'div'],
            ['<div>', 'div'],
            ['<div />', 'div'],
            ['<div></div>', 'div'],
            ['a', 'a'],
            ['<a>', 'a'],
            ['<a />', 'a'],
            ['<a></a>', 'a']
        ])
            assert.strictEqual(
                $.Tools.class.getDomNodeName(test[0]), test[1])
    })
    if (roundType === 'withJQuery')
        this.test(`grabDomNode (${roundType})`, (assert:Object):void => {
            for (const test:Array<any> of [
                [
                    [{
                        qunit: 'body div#qunit',
                        qunitFixture: 'body div#qunit-fixture'
                    }],
                    {
                        qunit: $('body div#qunit'),
                        qunitFixture: $('body div#qunit-fixture'),
                        parent: $('body')
                    }
                ],
                [
                    [{
                        qunit: 'div#qunit',
                        qunitFixture: 'div#qunit-fixture'
                    }],
                    {
                        parent: $('body'),
                        qunit: $('body div#qunit'),
                        qunitFixture: $('body div#qunit-fixture')
                    }
                ],
                [
                    [
                        {
                            qunit: 'div#qunit',
                            qunitFixture: 'div#qunit-fixture'
                        },
                        'body'
                    ],
                    {
                        parent: $('body'),
                        qunit: $('body').find('div#qunit'),
                        qunitFixture: $('body').find('div#qunit-fixture')
                    }
                ]
            ]) {
                const $domNodes = tools.grabDomNode.apply(tools, test[0])
                delete $domNodes.window
                delete $domNodes.document
                assert.deepEqual($domNodes, test[1])
            }
        })
    // // endregion
    // // region scope
    this.test(`isolateScope (${roundType})`, (assert:Object):void => {
        assert.deepEqual($.Tools.class.isolateScope({}), {})
        assert.deepEqual($.Tools.class.isolateScope({a: 2}), {a: 2})
        assert.deepEqual($.Tools.class.isolateScope({
            a: 2, b: {a: [1, 2]}
        }), {a: 2, b: {a: [1, 2]}})
        let scope = function():void {
            this.a = 2
        }
        scope.prototype = {b: 2, _a: 5}
        scope = new scope()
        assert.deepEqual($.Tools.class.isolateScope(scope), {
            _a: 5, a: 2, b: undefined
        })
        scope.b = 3
        assert.deepEqual(
            $.Tools.class.isolateScope(scope), {_a: 5, a: 2, b: 3})
        assert.deepEqual($.Tools.class.isolateScope(scope, []), {
            _a: undefined, a: 2, b: 3})
        scope._a = 6
        assert.deepEqual(
            $.Tools.class.isolateScope(scope), {_a: 6, a: 2, b: 3})
        scope = function():void {
            this.a = 2
        }
        scope.prototype = {b: 3}
        assert.deepEqual($.Tools.class.isolateScope(
            new scope(), ['b']
        ), {a: 2, b: 3})
        assert.deepEqual($.Tools.class.isolateScope(new scope()), {
            a: 2, b: undefined
        })
    })
    this.test(`determineUniqueScopeName (${roundType})`, (
        assert:Object
    ):void => {
        assert.ok($.Tools.class.determineUniqueScopeName().startsWith(
            'callback'))
        assert.ok($.Tools.class.determineUniqueScopeName('hans').startsWith(
            'hans'))
        assert.ok($.Tools.class.determineUniqueScopeName(
            'hans', '', {}
        ).startsWith('hans'))
        assert.strictEqual($.Tools.class.determineUniqueScopeName(
            'hans', '', {}, 'peter'
        ), 'peter')
        assert.ok($.Tools.class.determineUniqueScopeName(
            'hans', '', {peter: 2}, 'peter'
        ).startsWith('hans'))
        const name:string = $.Tools.class.determineUniqueScopeName(
            'hans', 'klaus', {peter: 2}, 'peter')
        assert.ok(name.startsWith('hans'))
        assert.ok(name.endsWith('klaus'))
        assert.ok(name.length > 'hans'.length + 'klaus'.length)
    })
    // // endregion
    // // region function handling
    this.test(`getMethod (${roundType})`, (assert:Object):void => {
        const testObject = {value: false}

        tools.getMethod(():void => {
            testObject.value = true
        })()
        assert.ok(testObject.value)
        tools.getMethod(function():void {
            this.value = false
        }, testObject)()
        assert.notOk(testObject.value)

        assert.strictEqual(tools.getMethod((
            five:5, two:2, three:3
        ):number => five + two + three, testObject, 5)(2, 3), 10)
    })
    this.test(`identity (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [2, 2],
            ['', ''],
            [undefined, undefined],
            [null, null],
            ['hans', 'hans']
        ])
            assert.strictEqual($.Tools.class.identity(test[0]), test[1])
        assert.ok($.Tools.class.identity({}) !== {})
        const testObject = {}
        assert.strictEqual($.Tools.class.identity(testObject), testObject)
    })
    this.test(`invertArrayFilter (${roundType})`, (assert:Object):void => {
        assert.deepEqual($.Tools.class.invertArrayFilter(
            $.Tools.class.arrayDeleteEmptyItems
        )([{a: null}]), [{a: null}])
        assert.deepEqual($.Tools.class.invertArrayFilter(
            $.Tools.class.arrayExtractIfMatches
        )(['a', 'b'], '^a$'), ['b'])
    })
    // // endregion
    // // region event
    this.test(`debounce (${roundType})`, (assert:Object):void => {
        let testValue = false
        $.Tools.class.debounce(():void => {
            testValue = true
        })()
        assert.ok(testValue)
        $.Tools.class.debounce(():void => {
            testValue = false
        }, 1000)()
        assert.notOk(testValue)
    })
    this.test(`fireEvent (${roundType})`, (assert:Object):void => {
        let testValue = false

        assert.strictEqual($.Tools({onClick: ():void => {
            testValue = true
        }}).fireEvent('click', true), true)
        assert.ok(testValue)
        assert.strictEqual($.Tools({onClick: ():void => {
            testValue = false
        }}).fireEvent('click', true), true)
        assert.notOk(testValue)
        assert.strictEqual(tools.fireEvent('click'), false)
        assert.notOk(testValue)
        tools.onClick = ():void => {
            testValue = true
        }
        assert.strictEqual(tools.fireEvent('click'), false)
        assert.ok(testValue)
        tools.onClick = ():void => {
            testValue = false
        }
        assert.strictEqual(tools.fireEvent('click', true), false)
        assert.ok(testValue)
    })
    if (roundType === 'withJQuery') {
        this.test(`on (${roundType})`, (assert:Object):void => {
            let testValue = false
            assert.strictEqual(tools.on('body', 'click', ():void => {
                testValue = true
            })[0], $('body')[0])

            $('body').trigger('click')
            assert.ok(testValue)
        })
        this.test(`off (${roundType})`, (assert:Object):void => {
            let testValue = false
            assert.strictEqual(tools.on('body', 'click', ():void => {
                testValue = true
            })[0], $('body')[0])
            assert.strictEqual(tools.off('body', 'click')[0], $('body')[0])

            $('body').trigger('click')
            assert.notOk(testValue)
        })
    }
    // // endregion
    // // region object
    this.test(`determineType (${roundType})`, (assert:Object):void => {
        assert.strictEqual($.Tools.class.determineType(), 'undefined')
        for (const test:Array<any> of [
            [undefined, 'undefined'],
            [{}.notDefined, 'undefined'],
            [null, 'null'],
            [true, 'boolean'],
            [new Boolean(), 'boolean'],
            [3, 'number'],
            [new Number(3), 'number'],
            ['', 'string'],
            [new String(''), 'string'],
            ['test', 'string'],
            [new String('test'), 'string'],
            [function():void {}, 'function'],
            [():void => {}, 'function'],
            [[], 'array'],
            /* eslint-disable no-array-constructor */
            // IgnoreTypeCheck
            [new Array(), 'array'],
            /* eslint-enable no-array-constructor */
            [new Date(), 'date'],
            [new Error(), 'error'],
            [/test/, 'regexp']
        ])
            assert.strictEqual(
                $.Tools.class.determineType(test[0]), test[1])
    })
    this.test(`convertSubstringInPlainObject (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [{}, /a/, '', {}],
            [{a: 'a'}, /a/, 'b', {a: 'b'}],
            [{a: 'aa'}, /a/, 'b', {a: 'ba'}],
            [{a: 'aa'}, /a/g, 'b', {a: 'bb'}],
            [{a: {a: 'aa'}}, /a/g, 'b', {a: {a: 'bb'}}]
        ])
            assert.deepEqual($.Tools.class.convertSubstringInPlainObject(
                test[0], test[1], test[2]
            ), test[3])
    })
    this.test(`modifyObject (${roundType})`, (assert:Object):void => {
        for (const test:any of [
            [[{}, {}], {}, {}],
            [[{a: 2}, {}], {a: 2}, {}],
            [[{a: 2}, {b: 1}], {a: 2}, {b: 1}],
            [[{a: 2}, {__remove__: 'a'}], {}, {}],
            [[{a: 2}, {__remove__: ['a']}], {}, {}],
            [[{a: [2]}, {a: {__prepend__: 1}}], {a: [1, 2]}, {}],
            [[{a: [2]}, {a: {__remove__: 1}}], {a: [2]}, {}],
            [[{a: [2, 1]}, {a: {__remove__: 1}}], {a: [2]}, {}],
            [[{a: [2, 1]}, {a: {__remove__: [1, 2]}}], {a: []}, {}],
            [[{a: [1]}, {a: {__remove__: 1}}], {a: []}, {}],
            [[{a: [1]}, {a: {__remove__: [1, 2]}}], {a: []}, {}],
            [[{a: [2]}, {a: {__append__: 1}}], {a: [2, 1]}, {}],
            [[{a: [2]}, {a: {__append__: [1, 2]}}], {a: [2, 1, 2]}, {}],
            [
                [{a: [2]}, {a: {__append__: [1, 2]}, b: 1}],
                {a: [2, 1, 2]}, {b: 1}
            ],
            [
                [{a: [2]}, {a: {__prepend__: 1}}, '_r', '_p'],
                {a: [2]}, {a: {__prepend__: 1}}
            ]
        ]) {
            assert.deepEqual($.Tools.class.modifyObject.apply(
                $.Tools, test[0]
            ), test[1])
            assert.deepEqual(test[0][1], test[2])
        }
    })
    this.test(`extendObject (${roundType})`, (assert:Object):void => {
        for (const test:any of [
            [[[]], []],
            [[{}], {}],
            [[{a: 1}], {a: 1}],
            [[{a: 1}, {a: 2}], {a: 2}],
            [[{}, {a: 1}, {a: 2}], {a: 2}],
            [[{}, {a: 1}, {a: 2}], {a: 2}],
            [[{a: 1, b: {a: 1}}, {a: 2, b: {b: 1}}], {a: 2, b: {b: 1}}],
            [[[1, 2], [1]], [1]],
            [[new Map()], new Map()],
            [[new Map([['a', 1]])], new Map([['a', 1]])],
            [
                [new Map([['a', 1]]), new Map([['a', 2]])],
                new Map([['a', 2]])
            ],
            [
                [new Map(), new Map([['a', 1]]), new Map([['a', 2]])],
                new Map([['a', 2]])
            ],
            [
                [new Map(), new Map([['a', 1]]), new Map([['a', 2]])],
                new Map([['a', 2]])
            ],
            [
                [
                    new Map([['a', 1], ['b', new Map([['a', 1]])]]),
                    new Map([['a', 2], ['b', new Map([['b', 1]])]])
                ],
                new Map([['a', 2], ['b', new Map([['b', 1]])]])
            ],
            [[true, {}], {}],
            [
                [true, {a: 1, b: {a: 1}}, {a: 2, b: {b: 1}}],
                {a: 2, b: {a: 1, b: 1}}
            ],
            [
                [true, {a: 1, b: {a: []}}, {a: 2, b: {b: 1}}],
                {a: 2, b: {a: [], b: 1}}
            ],
            [[true, {a: {a: [1, 2]}}, {a: {a: [3, 4]}}], {a: {a: [3, 4]}}],
            [
                [true, {a: {a: [1, 2]}}, {a: {a: null}}],
                {a: {a: null}}
            ],
            [[true, {a: {a: [1, 2]}}, {a: true}], {a: true}],
            [[true, {a: {_a: 1}}, {a: {b: 2}}], {a: {_a: 1, b: 2}}],
            [[false, {_a: 1}, {a: 2}], {a: 2, _a: 1}],
            [[true, {a: {a: [1, 2]}}, false], false],
            [[true, {a: {a: [1, 2]}}, undefined], undefined],
            [[true, {a: 1}, {a: 2}, {a: 3}], {a: 3}],
            [[true, [1], [1, 2]], [1, 2]],
            [[true, [1, 2], [1]], [1]],
            [[true, new Map()], new Map()],
            [
                [
                    true, new Map([['a', 1], ['b', new Map([['a', 1]])]]),
                    new Map([['a', 2], ['b', new Map([['b', 1]])]])
                ],
                new Map([['a', 2], ['b', new Map([['a', 1], ['b', 1]])]])
            ],
            [
                [
                    true, new Map([['a', 1], ['b', new Map([['a', []]])]]),
                    new Map([['a', 2], ['b', new Map([['b', 1]])]])
                ],
                new Map([['a', 2], ['b', new Map([['a', []], ['b', 1]])]])
            ],
            [
                [
                    true, new Map([['a', new Map([['a', [1, 2]]])]]),
                    new Map([['a', new Map([['a', [3, 4]]])]])
                ],
                new Map([['a', new Map([['a', [3, 4]]])]])
            ]
        ])
            assert.deepEqual($.Tools.class.extendObject.apply(
                $.Tools, test[0]
            ), test[1])
        assert.strictEqual(
            $.Tools.class.extendObject([1, 2], undefined), undefined)
        assert.strictEqual($.Tools.class.extendObject([1, 2], null), null)
        const target:Object = {a: [1, 2]}
        $.Tools.class.extendObject(true, target, {a: [3, 4]})
        assert.deepEqual(target, {a: [3, 4]})
    })
    this.test(`unwrapProxy (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [{}, {}],
            [{a: 'a'}, {a: 'a'}],
            [{a: 'aa'}, {a: 'aa'}],
            [{a: {__target__: 2}}, {a: 2}],
            [{a: {__target__: {__target__: 2}}}, {a: 2}]
        ])
            assert.deepEqual($.Tools.class.unwrapProxy(test[0]), test[1])
    })
    this.test(`addDynamicGetterAndSetter (${roundType})`, (
        assert:Object
    ):void => {
        assert.strictEqual(
            $.Tools.class.addDynamicGetterAndSetter(null), null)
        assert.strictEqual(
            $.Tools.class.addDynamicGetterAndSetter(true), true)
        assert.notDeepEqual(
            $.Tools.class.addDynamicGetterAndSetter({}), {})
        assert.ok($.Tools.class.addDynamicGetterAndSetter({
        }).__target__ instanceof Object)
        const mockup = {}
        assert.strictEqual($.Tools.class.addDynamicGetterAndSetter(
            mockup
        ).__target__, mockup)
        assert.deepEqual(
            $.Tools.class.addDynamicGetterAndSetter({}).__target__, {})
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter({a: 1}, (
            value:any
        ):any => value + 2).a, 3)
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter(
            {a: {a: 1}}, (value:any):any => (
                value instanceof Object
            ) ? value : value + 2).a.a, 3)
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter({a: {a: [{
            a: 1
        }]}}, (value:any):any => (
            value instanceof Object
        ) ? value : value + 2).a.a[0].a, 3)
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter(
            {a: {a: 1}}, (value:any):any =>
                (value instanceof Object) ? value : value + 2,
            (key:any, value:any):any => value, '[]', '[]',
            'hasOwnProperty', false
        ).a.a, 1)
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter(
            {a: 1}, (value:any):any =>
                (value instanceof Object) ? value : value + 2,
            (key:any, value:any):any => value, '[]', '[]',
            'hasOwnProperty', false, []
        ).a, 1)
        assert.deepEqual($.Tools.class.addDynamicGetterAndSetter(
            {a: new Map([['a', 1]])}, (value:any):any =>
                (value instanceof Object) ? value : value + 2,
            (key:any, value:any):any => value, 'get', 'set', 'has', true, [
                Map]
        ).a.a, 3)
    })
    this.test(`resolveDynamicDataStructure (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[null], null],
            [[false], false],
            [['1'], '1'],
            [[3], 3],
            [[{}], {}],
            [[{__evaluate__: '1'}], 1],
            [[{__evaluate__: "'1'"}], '1'],
            [[{a: {__evaluate__: "'a'"}}], {a: 'a'}],
            [[{a: {__evaluate__: 'self.a'}}, ['self'], [{a: 1}]], {a: 1}],
            [
                [{a: {__evaluate__: 'self.a'}}, ['self'], [{a: 1}], false],
                {a: {__evaluate__: 'self.a'}}
            ],
            [
                [
                    {a: {__evaluate__: 'self.a'}}, ['self'], [{a: 1}],
                    true, '__run__'
                ],
                {a: {__evaluate__: 'self.a'}}
            ],
            [
                [
                    {a: {__run__: 'self.a'}}, ['self'], [{a: 1}], true,
                    '__run__'
                ],
                {a: 1}
            ],
            [
                [
                    {a: [{__run__: 'self.a'}]}, ['self'], [{a: 1}], true,
                    '__run__'
                ],
                {a: [1]}
            ],
            [
                [{a: {__evaluate__: 'self.b'}, b: 2}, ['self']],
                {a: 2, b: 2}
            ],
            [
                [{
                    a: {__evaluate__: 'self.b'},
                    b: {__evaluate__: 'self.c'},
                    c: 2
                }, ['self']],
                {a: 2, b: 2, c: 2}
            ],
            [
                [{
                    a: {__execute__: 'return self.b'},
                    b: {__execute__: 'return self.c'},
                    c: 2
                }, ['self']],
                {a: 2, b: 2, c: 2}
            ]
        ])
            assert.deepEqual(
                $.Tools.class.resolveDynamicDataStructure.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`convertCircularObjectToJSON (${roundType})`, (
        assert:Object
    ):void => {
        let testObject1:Object = {}
        const testObject2:Object = {a: testObject1}
        testObject1.a = testObject2
        for (const test:Array<any> of [
            [{}, '{}'],
            [{a: null}, '{"a":null}'],
            [{a: {a: 2}}, '{"a":{"a":2}}'],
            [testObject1, '{"a":{"a":"__circularReference__"}}']
        ])
            assert.deepEqual(
                $.Tools.class.convertCircularObjectToJSON(test[0]), test[1]
            )
    })
    this.test(`convertPlainObjectToMap (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[null], null],
            [[true], true],
            [[0], 0],
            [[2], 2],
            [['a'], 'a'],
            [[{}], new Map()],
            [[[{}]], [new Map()]],
            [[[{}], false], [{}]],
            [[[{a: {}, b: 2}]], [new Map([['a', new Map()], ['b', 2]])]],
            [[[{b: 2, a: {}}]], [new Map([['a', new Map()], ['b', 2]])]],
            [
                [[{b: 2, a: new Map()}]],
                [new Map([['a', new Map()], ['b', 2]])]
            ],
            [
                [[{b: 2, a: [{}]}]],
                [new Map([['a', [new Map()]], ['b', 2]])]
            ]
        ])
            assert.deepEqual($.Tools.class.convertPlainObjectToMap.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`convertMapToPlainObject (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[null], null],
            [[true], true],
            [[0], 0],
            [[2], 2],
            [['a'], 'a'],
            [[new Map()], {}],
            [[[new Map()]], [{}]],
            [[[new Map()], false], [new Map()]],
            [[[new Map([['a', 2], [2, 2]])]], [{a: 2, '2': 2}]],
            [[[new Map([['a', new Map()], [2, 2]])]], [{a: {}, '2': 2}]],
            [
                [[new Map([['a', new Map([['a', 2]])], [2, 2]])]],
                [{a: {a: 2}, '2': 2}]
            ]
        ])
            assert.deepEqual($.Tools.class.convertMapToPlainObject.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`forEachSorted (${roundType})`, (assert:Object):void => {
        let result = []
        const tester = (item:Array<any>|Object):Array<any> =>
            $.Tools.class.forEachSorted(
                item, (value:any, key:string|number):number =>
                    result.push([key, value]))
        tester({})
        assert.deepEqual(result, [])
        assert.deepEqual(tester({}), [])
        assert.deepEqual(tester([]), [])
        assert.deepEqual(tester({a: 2}), ['a'])
        assert.deepEqual(tester({b: 1, a: 2}), ['a', 'b'])
        result = []
        tester({b: 1, a: 2})
        assert.deepEqual(result, [['a', 2], ['b', 1]])
        result = []

        tester([2, 2])
        assert.deepEqual(result, [[0, 2], [1, 2]])
        result = []
        tester({'5': 2, '6': 2, '2': 3})
        assert.deepEqual(result, [['2', 3], ['5', 2], ['6', 2]])
        result = []
        tester({a: 2, c: 2, z: 3})
        assert.deepEqual(result, [['a', 2], ['c', 2], ['z', 3]])
        $.Tools.class.forEachSorted([1], function():number {
            result = this
            return result
        }, 2)
        assert.deepEqual(result, 2)
    })
    this.test(`sort (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[], []],
            [{}, []],
            [[1], [0]],
            [[1, 2, 3], [0, 1, 2]],
            [[3, 2, 1], [0, 1, 2]],
            [[2, 3, 1], [0, 1, 2]],
            [{'1': 2, '2': 5, '3': 'a'}, ['1', '2', '3']],
            [{'2': 2, '1': 5, '-5': 'a'}, ['-5', '1', '2']],
            [{'3': 2, '2': 5, '1': 'a'}, ['1', '2', '3']],
            [{a: 2, b: 5, c: 'a'}, ['a', 'b', 'c']],
            [{c: 2, b: 5, a: 'a'}, ['a', 'b', 'c']],
            [{b: 2, c: 5, z: 'a'}, ['b', 'c', 'z']]
        ])
            assert.deepEqual($.Tools.class.sort(test[0]), test[1])
    })
    this.test(`equals (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [1, 1],
            [new Date(), new Date()],
            [new Date(1995, 11, 17), new Date(1995, 11, 17)],
            [/a/, /a/],
            [{a: 2}, {a: 2}],
            [{a: 2, b: 3}, {a: 2, b: 3}],
            [[1, 2, 3], [1, 2, 3]],
            [[], []],
            [{}, {}],
            [[1, 2, 3, {a: 2}], [1, 2, 3, {a: 2}]],
            [[1, 2, 3, [1, 2]], [1, 2, 3, [1, 2]]],
            [[{a: 1}], [{a: 1}]],
            [[{a: 1, b: 1}], [{a: 1}], []],
            [[{a: 1, b: 1}], [{a: 1}], ['a']],
            [2, 2, 0],
            [[{a: 1, b: 1}], [{a: 1}], null, 0],
            [[{a: 1}, {b: 1}], [{a: 1}, {b: 1}], null, 1],
            [[{a: {b: 1}}, {b: 1}], [{a: 1}, {b: 1}], null, 1],
            [[{a: {b: 1}}, {b: 1}], [{a: {b: 1}}, {b: 1}], null, 2],
            [[{a: {b: {c: 1}}}, {b: 1}], [{a: {b: 1}}, {b: 1}], null, 2],
            [
                [{a: {b: {c: 1}}}, {b: 1}], [{a: {b: 1}}, {b: 1}], null, 3,
                ['b']
            ],
            [():void => {}, ():void => {}]
        ])
            assert.ok($.Tools.class.equals.apply(this, test))
        for (const test:Array<any> of [
            [[{a: {b: 1}}, {b: 1}], [{a: 1}, {b: 1}], null, 2],
            [[{a: {b: {c: 1}}}, {b: 1}], [{a: {b: 1}}, {b: 1}], null, 3],
            [new Date(1995, 11, 17), new Date(1995, 11, 16)],
            [/a/i, /a/],
            [1, 2],
            [{a: 2, b: 3}, {a: 2}],
            [[1, 2, 3, 4], [1, 2, 3, 5]],
            [[1, 2, 3, 4], [1, 2, 3]],
            [[1, 2, 3, {a: 2}], [1, 2, 3, {b: 2}]],
            [[1, 2, 3, [1, 2]], [1, 2, 3, [1, 2, 3]]],
            [[1, 2, 3, [1, 2, 3]], [1, 2, 3, [1, 2]]],
            [[1, 2, 3, [1, 2, 3]], [1, 2, 3, [1, 2, {}]]],
            [[{a: 1, b: 1}], [{a: 1}]],
            [[{a: 1, b: 1}], [{a: 1}], ['a', 'b']],
            [1, 2, 0],
            [[{a: 1}, {b: 1}], [{a: 1}], null, 1],
            [():void => {}, ():void => {}, null, -1, [], false]
        ])
            assert.notOk($.Tools.class.equals.apply(this, test))
        const test = ():void => {}
        assert.ok($.Tools.class.equals(test, test, null, -1, [], false))
    })
    this.test(`copyLimitedRecursively (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[21], 21],
            [[0, -1], 0],
            [[0, 1], 0],
            [[0, 10], 0],
            [[new Date(0)], new Date(0)],
            [[/a/], /a/],
            [[{}], {}],
            [[{}, -1], {}],
            [[[]], []],
            [[new Map(), -1], new Map()],
            [[{a: 2}, 0], {a: 2}],
            [[{a: {a: 2}}, 0], {a: null}],
            [[{a: {a: 2}}, 1], {a: {a: 2}}],
            [[{a: {a: 2}}, 2], {a: {a: 2}}],
            [[{a: [{a: 2}]}, 1], {a: [null]}],
            [[{a: [{a: 2}]}, 2], {a: [{a: 2}]}],
            [[{a: {a: 2}}, 10], {a: {a: 2}}],
            [[new Map([['a', 2]]), 0], new Map([['a', 2]])],
            [
                [new Map([['a', new Map([['a', 2]])]]), 0],
                new Map([['a', null]])
            ],
            [
                [new Map([['a', new Map([['a', 2]])]]), 1],
                new Map([['a', new Map([['a', 2]])]])
            ],
            [
                [new Map([['a', new Map([['a', 2]])]]), 2],
                new Map([['a', new Map([['a', 2]])]])
            ],
            [
                [new Map([['a', [new Map([['a', 2]])]]]), 1],
                new Map([['a', [null]]])
            ],
            [
                [new Map([['a', [new Map([['a', 2]])]]]), 2],
                new Map([['a', [new Map([['a', 2]])]]])
            ],
            [
                [new Map([['a', new Map([['a', 2]])]]), 10],
                new Map([['a', new Map([['a', 2]])]])
            ]
        ])
            assert.deepEqual($.Tools.class.copyLimitedRecursively.apply(
                this, test[0]), test[1])
    })
    // // endregion
    // // region array
    this.test(`arrayMerge (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[], [], []],
            [[1], [], [1]],
            [[], [1], [1]],
            [[1], [1], [1, 1]],
            [[1, 2, 3, 1], [1, 2, 3], [1, 2, 3, 1, 1, 2, 3]]
        ])
            assert.deepEqual(
                $.Tools.class.arrayMerge(test[0], test[1]), test[2])
    })
    this.test(`arrayMake (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[], []],
            [[1, 2, 3], [1, 2, 3]],
            [1, [1]]
        ])
            assert.deepEqual($.Tools.class.arrayMake(test[0]), test[1])
    })
    this.test(`arrayUnique (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[1, 2, 3, 1], [1, 2, 3]],
            [[1, 2, 3, 1, 2, 3], [1, 2, 3]],
            [[], []],
            [[1, 2, 3], [1, 2, 3]]
        ])
            assert.deepEqual($.Tools.class.arrayUnique(test[0]), test[1])
    })
    this.test(`arrayAggregatePropertyIfEqual (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[[{a: 'b'}], 'a'], 'b'],
            [[[{a: 'b'}, {a: 'b'}], 'a'], 'b'],
            [[[{a: 'b'}, {a: 'c'}], 'a'], ''],
            [[[{a: 'b'}, {a: 'c'}], 'a', false], false]
        ])
            assert.strictEqual(
                $.Tools.class.arrayAggregatePropertyIfEqual.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`arrayDeleteEmptyItems (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[[{a: null}]], []],
            [[[{a: null, b: 2}]], [{a: null, b: 2}]],
            [[[{a: null, b: 2}], ['a']], []],
            [[[], ['a']], []],
            [[[]], []]
        ])
            assert.deepEqual($.Tools.class.arrayDeleteEmptyItems.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`arrayExtract (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[[{a: 'b', c: 'd'}], ['a']], [{a: 'b'}]],
            [[[{a: 'b', c: 'd'}], ['b']], [{}]],
            [[[{a: 'b', c: 'd'}], ['c']], [{c: 'd'}]],
            [[[{a: 'b', c: 'd'}, {a: 3}], ['c']], [{c: 'd'}, {}]],
            [[[{a: 'b', c: 'd'}, {c: 3}], ['c']], [{c: 'd'}, {c: 3}]]
        ])
            assert.deepEqual(
                $.Tools.class.arrayExtract.apply(this, test[0]), test[1])
    })
    this.test(`arrayExtractIfMatches (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [['b'], /b/, ['b']],
            [['b'], 'b', ['b']],
            [['b'], 'a', []],
            [[], 'a', []],
            [['a', 'b'], '', ['a', 'b']],
            [['a', 'b'], '^$', []],
            [['a', 'b'], 'b', ['b']],
            [['a', 'b'], '[ab]', ['a', 'b']]
        ])
            assert.deepEqual($.Tools.class.arrayExtractIfMatches(
                test[0], test[1]
            ), test[2])
    })
    this.test(`arrayExtractIfPropertyExists (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[{a: 2}], 'a', [{a: 2}]],
            [[{a: 2}], 'b', []],
            [[], 'b', []],
            [[{a: 2}, {b: 3}], 'a', [{a: 2}]]
        ])
            assert.deepEqual($.Tools.class.arrayExtractIfPropertyExists(
                test[0], test[1]
            ), test[2])
    })
    this.test(`arrayExtractIfPropertyMatches (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[{a: 'b'}], {a: 'b'}, [{a: 'b'}]],
            [[{a: 'b'}], {a: '.'}, [{a: 'b'}]],
            [[{a: 'b'}], {a: 'a'}, []],
            [[], {a: 'a'}, []],
            [[{a: 2}], {b: /a/}, []],
            [
                [{mimeType: 'text/x-webm'}],
                {mimeType: new RegExp('^text/x-webm$')},
                [{mimeType: 'text/x-webm'}]
            ]
        ])
            assert.deepEqual($.Tools.class.arrayExtractIfPropertyMatches(
                test[0], test[1]
            ), test[2])
    })
    this.test(`arrayIntersect (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[['A'], ['A']], ['A']],
            [[['A', 'B'], ['A']], ['A']],
            [[[], []], []],
            [[[5], []], []],
            [[[{a: 2}], [{a: 2}]], [{a: 2}]],
            [[[{a: 3}], [{a: 2}]], []],
            [[[{a: 3}], [{b: 3}]], []],
            [[[{a: 3}], [{b: 3}], ['b']], []],
            [[[{a: 3}], [{b: 3}], ['b'], false], []],
            [[[{b: null}], [{b: null}], ['b']], [{b: null}]],
            [[[{b: null}], [{b: undefined}], ['b']], []],
            [[[{b: null}], [{b: undefined}], ['b'], false], [{b: null}]],
            [[[{b: null}], [{}], ['b'], false], [{b: null}]],
            [[[{b: undefined}], [{}], ['b'], false], [{b: undefined}]],
            [[[{}], [{}], ['b'], false], [{}]],
            [[[{b: null}], [{}], ['b']], []],
            [[[{b: undefined}], [{}], ['b'], true], [{b: undefined}]],
            [[[{b: 1}], [{a: 1}], {b: 'a'}, true], [{b: 1}]]
        ])
            assert.deepEqual(
                $.Tools.class.arrayIntersect.apply(this, test[0]), test[1])
    })
    this.test(`arrayMakeRange (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[[0]], [0]],
            [[[5]], [0, 1, 2, 3, 4, 5]],
            [[[]], []],
            [[[2, 5]], [2, 3, 4, 5]],
            [[[2, 10], 2], [2, 4, 6, 8, 10]]
        ])
            assert.deepEqual(
                $.Tools.class.arrayMakeRange.apply(this, test[0]), test[1])
    })
    this.test(`arraySumUpProperty (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[[{a: 2}, {a: 3}], 'a'], 5],
            [[[{a: 2}, {b: 3}], 'a'], 2],
            [[[{a: 2}, {b: 3}], 'c'], 0]
        ])
            assert.strictEqual($.Tools.class.arraySumUpProperty.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`arrayAppendAdd (${roundType})`, (assert:Object):void => {
        const testObject:Object = {}
        for (const test:Array<any> of [
            [[{}, {}, 'b'], {b: [{}]}],
            [[testObject, {a: 3}, 'b'], {b: [{a: 3}]}],
            [[testObject, {a: 3}, 'b'], {b: [{a: 3}, {a: 3}]}],
            [[{b: [2]}, 2, 'b', false], {b: [2, 2]}],
            [[{b: [2]}, 2, 'b'], {b: [2]}]
        ])
            assert.deepEqual(
                $.Tools.class.arrayAppendAdd.apply(this, test[0]), test[1])
    })
    this.test(`arrayRemove (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[[], 2], []],
            [[[2], 2], []],
            [[[2], 2, true], []],
            [[[1, 2], 2], [1]],
            [[[1, 2], 2, true], [1]]
        ])
            assert.deepEqual(
                $.Tools.class.arrayRemove.apply(this, test[0]), test[1])
        assert.throws(():?Array<any> => $.Tools.class.arrayRemove(
            [], 2, true
        ), Error("Given target doesn't exists in given list."))
    })
    // // endregion
    // // region string
    this.test('stringConvertToValidRegularExpression', (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[''], ''],
            [["that's no regex: .*$"], "that's no regex: \\.\\*\\$"],
            [
                ['-\\[]()^$*+.}-', '}'],
                '\\-\\\\[\\]\\(\\)\\^\\$\\*\\+\\.}\\-'
            ],
            [[
                '-\\[]()^$*+.{}-',
                ['[', ']', '(', ')', '^', '$', '*', '+', '.', '{']
            ], '\\-\\[]()^$*+.{\\}\\-'],
            [['-', '\\'], '\\-']
        ])
            assert.strictEqual(
                $.Tools.class.stringConvertToValidRegularExpression.apply(
                    this, test[0]
                ), test[1])
    })
    this.test('stringConvertToValidVariableName', (
        assert:Object
    ):void => {
        for (const test:Array<string> of [
            ['', ''],
            ['a', 'a'],
            ['_a', '_a'],
            ['_a_a', '_a_a'],
            ['_a-a', '_aA'],
            ['-a-a', 'aA'],
            ['-a--a', 'aA'],
            ['--a--a', 'aA']
        ])
            assert.strictEqual(
                $.Tools.class.stringConvertToValidVariableName(
                    test[0]
                ), test[1])
    })
    // /// region url handling
    this.test(`stringEncodeURIComponent (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[''], ''],
            [[' '], '+'],
            [[' ', true], '%20'],
            [['@:$, '], '@:$,+'],
            [['+'], '%2B']
        ])
            assert.strictEqual(
                $.Tools.class.stringEncodeURIComponent.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`stringAddSeparatorToPath (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [[''], ''],
            [['/'], '/'],
            [['/a'], '/a/'],
            [['/a/bb/'], '/a/bb/'],
            [['/a/bb'], '/a/bb/'],
            [['/a/bb', '|'], '/a/bb|'],
            [['/a/bb/', '|'], '/a/bb/|']
        ])
            assert.strictEqual(
                $.Tools.class.stringAddSeparatorToPath.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`stringHasPathPrefix (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['/admin', '/admin'],
            ['test', 'test'],
            ['', ''],
            ['a', 'a/b'],
            ['a/', 'a/b'],
            ['/admin', '/admin#test', '#']
        ])
            assert.ok($.Tools.class.stringHasPathPrefix.apply(this, test))
        for (const test:Array<any> of [
            ['b', 'a/b'],
            ['b/', 'a/b'],
            ['/admin/', '/admin/test', '#'],
            ['/admin', '/admin/test', '#']
        ])
            assert.notOk(
                $.Tools.class.stringHasPathPrefix.apply(this, test))
    })
    this.test(`stringGetDomainName (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [
                ['https://www.test.de/site/subSite?param=value#hash'],
                'www.test.de'
            ],
            [['a', true], true],
            [['http://www.test.de'], 'www.test.de'],
            [['http://a.de'], 'a.de'],
            [['http://localhost'], 'localhost'],
            [['localhost', 'a'], 'a'],
            [['a', $.global.location.hostname], $.global.location.hostname],
            [['//a'], 'a'],
            [
                [
                    'a/site/subSite?param=value#hash',
                    $.global.location.hostname
                ],
                $.global.location.hostname
            ],
            [
                [
                    '/a/site/subSite?param=value#hash',
                    $.global.location.hostname
                ],
                $.global.location.hostname
            ],
            [
                ['//alternate.local/a/site/subSite?param=value#hash'],
                'alternate.local'
            ],
            [['//alternate.local/'], 'alternate.local']
        ])
            assert.strictEqual($.Tools.class.stringGetDomainName.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`stringGetPortNumber (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [['https://www.test.de/site/subSite?param=value#hash'], 443],
            [['http://www.test.de'], 80],
            [['http://www.test.de', true], true],
            [['www.test.de', true], true],
            [['a', true], true],
            [['a', true], true],
            [['a:80'], 80],
            [['a:20'], 20],
            [['a:444'], 444],
            [['http://localhost:89'], 89],
            [['https://localhost:89'], 89]
        ])
            assert.strictEqual($.Tools.class.stringGetPortNumber.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`stringGetProtocolName (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [
                ['https://www.test.de/site/subSite?param=value#hash'],
                'https'
            ],
            [['http://www.test.de'], 'http'],
            [
                ['//www.test.de', $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)],
                $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)
            ],
            [['http://a.de'], 'http'],
            [['ftp://localhost'], 'ftp'],
            [
                ['a', $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)],
                $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)
            ],
            [
                [
                    'a/site/subSite?param=value#hash',
                    $.global.location.protocol.substring(
                        0, $.global.location.protocol.length - 1)
                ],
                $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)
            ],
            [['/a/site/subSite?param=value#hash', 'a'], 'a'],
            [
                ['alternate.local/a/site/subSite?param=value#hash', 'b'],
                'b'
            ],
            [['alternate.local/', 'c'], 'c'],
            [
                [
                    '', $.global.location.protocol.substring(
                        0, $.global.location.protocol.length - 1)
                ],
                $.global.location.protocol.substring(
                    0, $.global.location.protocol.length - 1)
            ]
        ])
            assert.strictEqual($.Tools.class.stringGetProtocolName.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`stringGetURLVariable (${roundType})`, (
        assert:Object
    ):void => {
        assert.ok(Array.isArray($.Tools.class.stringGetURLVariable()))
        assert.ok(Array.isArray($.Tools.class.stringGetURLVariable(
            null, '&')))
        assert.ok(Array.isArray($.Tools.class.stringGetURLVariable(
            null, '#')))
        for (const test:Array<any> of [
            [['notExisting'], undefined],
            [['notExisting', '&'], undefined],
            [['notExisting', '#'], undefined],
            [['test', '?test=2'], '2'],
            [['test', 'test=2'], '2'],
            [['test', 'test=2&a=2'], '2'],
            [['test', 'b=3&test=2&a=2'], '2'],
            [['test', '?b=3&test=2&a=2'], '2'],
            [['test', '?b=3&test=2&a=2'], '2'],
            [['test', '&', '$', '!', '', '#$test=2'], '2'],
            [['test', '&', '$', '!', '?test=4', '#$test=3'], '4'],
            [['a', '&', '$', '!', '?test=4', '#$test=3'], undefined],
            [['test', '#', '$', '!', '?test=4', '#$test=3'], '3'],
            [['test', '#', '$', '!', '', '#!test#$test=4'], '4'],
            [['test', '#', '$', '!', '', '#!/test/a#$test=4'], '4'],
            [['test', '#', '$', '!', '', '#!/test/a/#$test=4'], '4'],
            [['test', '#', '$', '!', '', '#!test/a/#$test=4'], '4'],
            [['test', '#', '$', '!', '', '#!/#$test=4'], '4'],
            [['test', '#', '$', '!', '', '#!test?test=3#$test=4'], '4'],
            [['test', '&', '?', '!', null, '#!a?test=3'], '3'],
            [['test', '&', '$', '!', null, '#!test#$test=4'], '4'],
            [['test', '&', '$', '!', null, '#!test?test=3#$test=4'], '4']
        ])
            assert.strictEqual($.Tools.class.stringGetURLVariable.apply(
                this, test[0]
            ), test[1])
    })
    this.test(`stringIsInternalURL (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [
                'https://www.test.de/site/subSite?param=value#hash',
                'https://www.test.de/site/subSite?param=value#hash'
            ],
            [
                '//www.test.de/site/subSite?param=value#hash',
                '//www.test.de/site/subSite?param=value#hash'
            ],
            [
                `${$.global.location.protocol}//www.test.de/site/subSite` +
                    '?param=value#hash',
                `${$.global.location.protocol}//www.test.de/site/subSite` +
                    `?param=value#hash`
            ],
            [
                'https://www.test.de:443/site/subSite?param=value#hash',
                'https://www.test.de/site/subSite?param=value#hash'
            ],
            [
                '//www.test.de:80/site/subSite?param=value#hash',
                '//www.test.de/site/subSite?param=value#hash'
            ],
            [$.global.location.href, $.global.location.href],
            ['1', $.global.location.href],
            ['#1', $.global.location.href],
            ['/a', $.global.location.href]
        ])
            assert.ok($.Tools.class.stringIsInternalURL.apply(this, test))
        for (const test:Array<any> of [
            [
                `${$.global.location.protocol}//www.test.de/site/subSite` +
                    '?param=value#hash',
                'ftp://www.test.de/site/subSite?param=value#hash'
            ],
            [
                'https://www.test.de/site/subSite?param=value#hash',
                'http://www.test.de/site/subSite?param=value#hash'
            ],
            [
                'http://www.test.de/site/subSite?param=value#hash',
                'test.de/site/subSite?param=value#hash'
            ],
            [
                `${$.global.location.protocol}//www.test.de:` +
                `${$.global.location.port}/site/subSite` +
                '?param=value#hash/site/subSite?param=value#hash'
            ],
            [
                `http://www.test.de:${$.global.location.port}/site/subSite?` +
                    'param=value#hash',
                'https://www.test.de/site/subSite?param=value#hash'
            ]
        ])
            assert.notOk($.Tools.class.stringIsInternalURL.apply(
                this, test))
    })
    this.test(`stringNormalizeURL (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['www.test.com', 'http://www.test.com'],
            ['test', 'http://test'],
            ['http://test', 'http://test'],
            ['https://test', 'https://test']
        ])
            assert.strictEqual(
                $.Tools.class.stringNormalizeURL(test[0]), test[1])
    })
    this.test(`stringRepresentURL (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['http://www.test.com', 'www.test.com'],
            ['ftp://www.test.com', 'ftp://www.test.com'],
            ['https://www.test.com', 'www.test.com'],
            [undefined, ''],
            [null, ''],
            [false, ''],
            [true, ''],
            ['', ''],
            [' ', '']
        ])
            assert.strictEqual(
                $.Tools.class.stringRepresentURL(test[0]), test[1])
    })
    // /// endregion
    this.test(`stringCompressStyleValue (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['', ''],
            [' border: 1px  solid red;', 'border:1px solid red'],
            ['border : 1px solid red ', 'border:1px solid red'],
            ['border : 1px  solid red ;', 'border:1px solid red'],
            ['border : 1px  solid red   ; ', 'border:1px solid red'],
            ['height: 1px ; width:2px ; ', 'height:1px;width:2px'],
            [';;height: 1px ; width:2px ; ;', 'height:1px;width:2px'],
            [' ;;height: 1px ; width:2px ; ;', 'height:1px;width:2px'],
            [';height: 1px ; width:2px ; ', 'height:1px;width:2px']
        ])
            assert.strictEqual(
                $.Tools.class.stringCompressStyleValue(test[0]), test[1])
    })
    this.test(`stringCamelCaseToDelimited (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [['hansPeter'], 'hans-peter'],
            [['hansPeter', '|'], 'hans|peter'],
            [[''], ''],
            [['h'], 'h'],
            [['hP', ''], 'hp'],
            [['hansPeter'], 'hans-peter'],
            [['hans-peter'], 'hans-peter'],
            [['hansPeter', '_'], 'hans_peter'],
            [['hansPeter', '+'], 'hans+peter'],
            [['Hans'], 'hans'],
            [['hansAPIURL', '-', ['api', 'url']], 'hans-api-url'],
            [['hansPeter', '-', []], 'hans-peter']
        ])
            assert.strictEqual(
                $.Tools.class.stringCamelCaseToDelimited.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`stringCapitalize (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            ['hansPeter', 'HansPeter'],
            ['', ''],
            ['a', 'A'],
            ['A', 'A'],
            ['AA', 'AA'],
            ['Aa', 'Aa'],
            ['aa', 'Aa']
        ])
            assert.strictEqual(
                $.Tools.class.stringCapitalize(test[0]), test[1])
    })
    this.test(`stringDelimitedToCamelCase (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [['hans-peter'], 'hansPeter'],
            [['hans|peter', '|'], 'hansPeter'],
            [[''], ''],
            [['h'], 'h'],
            [['hans-peter'], 'hansPeter'],
            [['hans--peter'], 'hans-Peter'],
            [['Hans-Peter'], 'HansPeter'],
            [['-Hans-Peter'], '-HansPeter'],
            [['-'], '-'],
            [['hans-peter', '_'], 'hans-peter'],
            [['hans_peter', '_'], 'hansPeter'],
            [['hans_id', '_'], 'hansID'],
            [['url_hans_id', '_', ['hans']], 'urlHANSId'],
            [['url_hans_1', '_'], 'urlHans1'],
            [['hansUrl1', '-', ['url'], true], 'hansUrl1'],
            [['hans-url', '-', ['url'], true], 'hansURL'],
            [['hans-Url', '-', ['url'], true], 'hansUrl'],
            [['hans-Url', '-', ['url'], false], 'hansURL'],
            [['hans-Url', '-', [], false], 'hansUrl'],
            [['hans--Url', '-', [], false, true], 'hansUrl']
        ])
            assert.strictEqual(
                $.Tools.class.stringDelimitedToCamelCase.apply(
                    this, test[0]
                ), test[1])
    })
    this.test(`stringFormat (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [['{1}', 'test'], 'test'],
            [['', 'test'], ''],
            [['{1}'], '{1}'],
            [['{1} test {2} - {2}', 1, 2], '1 test 2 - 2']
        ])
            assert.strictEqual(
                $.Tools.class.stringFormat.apply(this, test[0]), test[1])
    })
    this.test(`stringGetRegularExpressionValidated (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ["that's no regex: .*$", "that's no regex: \\.\\*\\$"],
            ['', ''],
            ['-[]()^$*+.}-\\', '\\-\\[\\]\\(\\)\\^\\$\\*\\+\\.\\}\\-\\\\'],
            ['-', '\\-']
        ])
            assert.strictEqual(
                $.Tools.class.stringGetRegularExpressionValidated(test[0]),
                test[1])
    })
    this.test(`stringLowerCase (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            ['HansPeter', 'hansPeter'],
            ['', ''],
            ['A', 'a'],
            ['a', 'a'],
            ['aa', 'aa'],
            ['Aa', 'aa'],
            ['aa', 'aa']
        ])
            assert.strictEqual(
                $.Tools.class.stringLowerCase(test[0]), test[1])
    })
    this.test(`stringMark (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[''], ''],
            [['test', 'e'], 't<span class="tools-mark">e</span>st'],
            [['test', 'es'], 't<span class="tools-mark">es</span>t'],
            [['test', 'test'], '<span class="tools-mark">test</span>'],
            [['test', ''], 'test'],
            [['test', 'tests'], 'test'],
            [['', 'test'], ''],
            [['test', 'e', '<a>{1}</a>'], 't<a>e</a>st'],
            [['test', 'E', '<a>{1}</a>'], 't<a>e</a>st'],
            [['test', 'E', '<a>{1}</a>', false], 't<a>e</a>st'],
            [['tesT', 't', '<a>{1}</a>'], '<a>t</a>es<a>T</a>'],
            [
                ['tesT', 't', '<a>{1} - {1}</a>'],
                '<a>t - t</a>es<a>T - T</a>'
            ],
            [['test', 'E', '<a>{1}</a>', true], 'test']
        ])
            assert.strictEqual(
                $.Tools.class.stringMark.apply(this, test[0]), test[1])
    })
    this.test(`stringMD5 (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[''], 'd41d8cd98f00b204e9800998ecf8427e'],
            [['test'], '098f6bcd4621d373cade4e832627b4f6'],
            [['ä'], '8419b71c87a225a2c70b50486fbee545'],
            [['test', true], '098f6bcd4621d373cade4e832627b4f6'],
            [['ä', true], 'c15bcc5577f9fade4b4a3256190a59b0']
        ])
            assert.strictEqual(
                $.Tools.class.stringMD5.apply(this, test[0]), test[1])
    })
    this.test(`stringNormalizePhoneNumber (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['0', '0'],
            [0, '0'],
            ['+49 172 (0) / 0212 - 3', '0049172002123']
        ])
            assert.strictEqual(
                $.Tools.class.stringNormalizePhoneNumber(test[0]), test[1])
    })
    this.test(`stringRepresentPhoneNumber (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            ['0', '0'],
            ['0172-12321-1', '+49 (0) 172 / 123 21-1'],
            ['0172-123211', '+49 (0) 172 / 12 32 11'],
            ['0172-1232111', '+49 (0) 172 / 123 21 11'],
            [undefined, ''],
            [null, ''],
            [false, ''],
            [true, ''],
            ['', ''],
            [' ', '']
        ])
            assert.strictEqual(
                $.Tools.class.stringRepresentPhoneNumber(test[0]), test[1])
    })
    this.test(`stringDecodeHTMLEntities (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<string> of [
            ['', ''],
            ['<div></div>', '<div></div>'],
            ['<div>&amp;</div>', '<div>&</div>'],
            [
                '<div>&amp;&auml;&Auml;&uuml;&Uuml;&ouml;&Ouml;</div>',
                '<div>&äÄüÜöÖ</div>'
            ]
        ])
            assert.equal(
                $.Tools.class.stringDecodeHTMLEntities(test[0]), test[1])
    })
    this.test(`normalizeDomNodeSelector (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<string> of [
            ['div', 'body div'],
            ['div p', 'body div p'],
            ['body div', 'body div'],
            ['body div p', 'body div p'],
            ['', 'body']
        ])
            assert.strictEqual(
                tools.normalizeDomNodeSelector(test[0]), test[1])
        for (const test:string of [
            '',
            'div',
            'div, p'
        ])
            assert.strictEqual($.Tools({
                domNodeSelectorPrefix: ''
            }).normalizeDomNodeSelector(test), test)
    })
    // / endregion
    // // region number
    this.test(`numberIsNotANumber (${roundType})`, (
        assert:Object
    ):void => {
        for (const test:Array<any> of [
            [NaN, true],
            [{}, false],
            [undefined, false],
            [new Date().toString(), false],
            [null, false],
            [false, false],
            [true, false],
            [0, false]
        ])
            assert.strictEqual(
                $.Tools.class.numberIsNotANumber(test[0]), test[1])
    })
    this.test(`numberRound (${roundType})`, (assert:Object):void => {
        for (const test:Array<any> of [
            [[1.5, 0], 2],
            [[1.4, 0], 1],
            [[1.4, -1], 0],
            [[1000, -2], 1000],
            [[999, -2], 1000],
            [[950, -2], 1000],
            [[949, -2], 900],
            [[1.2345], 1],
            [[1.2345, 2], 1.23],
            [[1.2345, 3], 1.235],
            [[1.2345, 4], 1.2345],
            [[699, -2], 700],
            [[650, -2], 700],
            [[649, -2], 600]
        ])
            assert.strictEqual(
                $.Tools.class.numberRound.apply(this, test[0]), test[1])
    })
    // // endregion
    // // region data transfer
    if (
        typeof targetTechnology !== 'undefined' &&
        targetTechnology === 'web' && roundType === 'withJQuery'
    ) {
        this.test(`sendToIFrame (${roundType})`, (assert:Object):void => {
            const iFrame = $('<iframe>').hide().attr('name', 'test')
            $('body').append(iFrame)
            assert.ok($.Tools.class.sendToIFrame(
                iFrame, window.document.URL, {test: 5}, 'get', true))
        })
        this.test(`sendToExternalURL (${roundType})`, (
            assert:Object
        ):void => assert.ok(tools.sendToExternalURL(
            window.document.URL, {test: 5})))
    }
    // // endregion
    // / endregion
    // / region protected
    if (roundType === 'withJQuery')
        this.test(`_bindEventHelper (${roundType})`, (
            assert:Object
        ):void => {
            for (const test:Array<any> of [
                [['body']],
                [['body'], true],
                [['body'], false, 'bind']
            ])
                assert.ok(tools._bindEventHelper.apply(tools, test))
        })
    // / endregion
    // endregion
}, closeWindow: false, roundTypes: []}]
// endregion
// region test runner (in browserAPI)
let testRan:boolean = false
browserAPI((browserAPI:BrowserAPI):number => setTimeout(():void => {
    testRan = true
    // region configuration
    QUnit.config = require('./index').default.extendObject(QUnit.config || {
    }, {
        /*
        notrycatch: true,
        noglobals: true,
        */
        altertitle: true,
        autostart: true,
        fixture: '',
        hidepassed: false,
        maxDepth: 3,
        reorder: false,
        requireExpects: false,
        testTimeout: 30 * 1000,
        scrolltop: false
    })
    // endregion
    const testPromises:Array<Promise<any>> = []
    let closeWindow:boolean = false
    for (const test:Test of tests) {
        if (test.closeWindow)
            closeWindow = true
        for (const roundType:string of ['plain', 'withDocument', 'withJQuery'])
            if (test.roundTypes.length === 0 || test.roundTypes.includes(
                roundType
            )) {
                // NOTE: Enforce to reload module to rebind "$".
                delete require.cache[require.resolve('./index')]
                let $bodyDomNode:$DomNode
                let $:any
                if (roundType === 'plain') {
                    window.$ = null
                    $ = require('./index').$
                } else {
                    if (roundType === 'withJQuery') {
                        $ = require('jquery')
                        window.$ = $
                    }
                    $ = require('./index').$
                    $.context = window.document
                    $bodyDomNode = $('body')
                }
                const tools:$.Tools = (roundType === 'plain') ? $.Tools(
                ) : $('body').Tools()
                const testPromise:?Object = test.callback.call(
                    QUnit, roundType, (
                        typeof TARGET_TECHNOLOGY === 'undefined'
                    ) ? null : TARGET_TECHNOLOGY, $, browserAPI, tools,
                    $bodyDomNode)
                if (
                    typeof testPromise === 'object' && testPromise &&
                    'then' in testPromise
                )
                    testPromises.push(testPromise)
            }
    }
    Promise.all(testPromises).then(():void => {
        if (
            typeof TARGET_TECHNOLOGY === 'undefined' ||
            TARGET_TECHNOLOGY === 'node'
        ) {
            if (closeWindow)
                browserAPI.window.close()
            QUnit.load()
        }
    })
    // region hot module replacement handler
    /*
        NOTE: hot module replacement doesn't work with async tests yet since
        qunit is not resetable yet:

        if (typeof module === 'object' && 'hot' in module && module.hot) {
            module.hot.accept()
            // IgnoreTypeCheck
            module.hot.dispose(():void => {
                QUnit.reset()
                console.clear()
            }
        }
    */
    // endregion
}, 0))
// endregion
// region export test register function
let testRegistered:boolean = false
/**
 * Registers a complete test set.
 * @param callback - A function containing all tests to run. This callback gets
 * some useful parameters and will be executed in context of qunit.
 * @param roundTypes - A list of round types which should be avoided.
 * @param closeWindow - Indicates whether the window object should be closed
 * after finishing all tests.
 * @returns The list of currently registered tests.
 */
export default function(
    callback:((
        roundType:string, targetTechnology:?string, $:any,
        browserAPI:BrowserAPI, tools:Object, $bodyDomNode:$DomNode
    ) => any), roundTypes:Array<string> = [], closeWindow:boolean = false
):Array<Test> {
    if (testRan)
        throw Error(
            'You have to registere your tests immediately after importing ' +
            'the client node library.')
    if (!testRegistered) {
        testRegistered = true
        tests = []
    }
    tests.push({callback, closeWindow, roundTypes})
    return tests
}
// endregion
// region vim modline
// vim: set tabstop=4 shiftwidth=4 expandtab:
// vim: foldmethod=marker foldmarker=region,endregion:
// endregion
