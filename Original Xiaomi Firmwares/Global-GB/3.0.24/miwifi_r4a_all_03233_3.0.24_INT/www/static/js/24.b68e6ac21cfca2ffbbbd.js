webpackJsonp([24],{"4uQT":function(t,e,n){"use strict";var a={name:"headers",props:{name:{type:String,default:""},controlers:{type:String,default:""},step:{type:Number,default:1},fontsize:{type:String,default:"init"}},data:function(){return{stepMap:1}},methods:{back:function(){this.currentStep>1?this.$emit("goBack",--this.currentStep):1==this.currentStep&&history.go(-1)}},computed:{currentStep:{get:function(){return this.stepMap},set:function(t){this.stepMap=t}}},watch:{step:function(t){this.stepMap=t}}},s={render:function(){var t=this,e=t.$createElement,n=t._self._c||e;return n("div",{staticClass:"header"},[n("div",{staticClass:"title",class:{title26:"index"==t.fontsize}},[n("span",{staticClass:"iconfont fanhuijian",class:{iconfont26:"index"==t.fontsize},on:{click:t.back}}),t._v(" "),n("h3",{class:{font26:"index"==t.fontsize}},[t._v(t._s(t.name))])])])},staticRenderFns:[]};var i=n("VU/8")(a,s,!1,function(t){n("bMf1")},null,null);e.a=i.exports},bMf1:function(t,e){},hGY6:function(t,e){},hx1f:function(t,e,n){"use strict";Object.defineProperty(e,"__esModule",{value:!0});var a={name:"error",data:function(){return{pppoe:{pppoeName:"...",pppoePassword:"..."},operator_lists:[{name:"简体中文",lang:"zh_cn"},{name:"English",lang:"en"},{name:"русский",lang:"ru"},{name:"Español",lang:"es"},{name:"Україна",lang:"uk"},{name:"Italiano",lang:"it"},{name:"Français",lang:"fr"},{name:"Deutsch",lang:"de"},{name:"Türkçe",lang:"tr"},{name:"Português(Brasil)",lang:"pt"}]}},methods:{selectCountry:function(t){localStorage.setItem("lang",t.lang),this.$router.push({path:"/home",query:{name:t.name,lang:t.lang}})}},components:{Header:n("4uQT").a},created:function(){}},s={render:function(){var t=this,e=t.$createElement,n=t._self._c||e;return n("div",{staticClass:"container"},[n("Header",{attrs:{name:t.$t("SETTING_LANGUAGE")}}),t._v(" "),n("ul",{staticClass:"operators"},t._l(t.operator_lists,function(e){return n("li",{on:{click:function(n){return t.selectCountry(e)}}},[n("a",[n("div",{staticClass:"name"},[t._v("\n                  "+t._s(e.name)+"\n              ")]),t._v(" "),t._m(0,!0)])])}),0)],1)},staticRenderFns:[function(){var t=this.$createElement,e=this._self._c||t;return e("div",{staticClass:"tel"},[e("div",{staticClass:"iconfont icon-fanhui"})])}]};var i=n("VU/8")(a,s,!1,function(t){n("hGY6")},"data-v-b40f6270",null);e.default=i.exports}});