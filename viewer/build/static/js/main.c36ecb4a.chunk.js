(window.webpackJsonp=window.webpackJsonp||[]).push([[0],{10:function(e,t,n){e.exports=n(18)},16:function(e,t,n){},17:function(e,t,n){},18:function(e,t,n){"use strict";n.r(t);var a=n(0),s=n.n(a),o=n(4),r=n.n(o),c=(n(16),n(2)),i=n(5),u=n(6),m=n(9),l=n(7),f=n(1),g=n(8),d=(n(17),function(e){function t(e){var n;Object(i.a)(this,t),(n=Object(m.a)(this,Object(l.a)(t).call(this,e))).connect=function(){var e=new WebSocket("ws://localhost:9161");e.onopen=function(t){n.setState(function(e){return Object(c.a)({},e,{message:"Connected."})}),e.send("60")},e.onclose=function(e){n.setState(function(e){return Object(c.a)({},e,{message:"Disconnected."})}),setTimeout(n.connect,1e3)},e.onmessage=function(e){if("Success!"===e.data)console.log("Success");else if("Compiling"===e.data)n.setState({message:"Compiling..."}),n.status="compiling",n.svgs=[],n.frame_count=0,n.next_frame=0;else if("Done"===e.data)n.setState({message:""}),console.log("Done"),n.status="done";else if(e.data.startsWith("Error"))console.log("Error",e.data.substring(5)),n.setState({message:e.data.substring(5)});else{var t=parseInt(e.data);if(isNaN(t)){var a=document.createElement("div");a.innerHTML=e.data,n.svgs[n.next_frame]=a;var s=0;n.svgs.forEach(function(e){return s++}),console.log("Received",n.next_frame,n.frame_count,s)}else"compiling"===n.status?(n.setState({message:"Rendering..."}),n.frame_count=t,n.status="rendering",n.start=Date.now(),n.svgs=[],n.svgs[n.frame_count-1]=void 0):"rendering"===n.status?n.next_frame=t:console.log("Bad state change: received number")}},n.setState(function(t){return Object(c.a)({},t,{socket:e,message:"Connecting..."})})},n.onLoad=function(e){setTimeout(function(){e.resize()},0)},n.state={},setTimeout(n.connect,0),n.svgs=[],n.start=Date.now(),n.status="",n.frame_count=0,n.next_frame=0;var a=Object(f.a)(n);return requestAnimationFrame(function e(){var t=Date.now(),s=a.frame_count,o=a.frame_count/60,r=Math.round((t-n.start)/1e3*60)%s,c=0;if(n.svgs.forEach(function(e){return c++}),s){if(a.svgs[r]){for(n.setState({message:r+"/"+a.frame_count+" "+Math.round(c/o)+" fps"});a.svg.firstChild;)a.svg.removeChild(a.svg.firstChild);a.svg.appendChild(a.svgs[r])}}else a.svg.innerText="";requestAnimationFrame(e)}),n}return Object(g.a)(t,e),Object(u.a)(t,[{key:"render",value:function(){var e=this,t=this.state.message;return s.a.createElement("div",{className:"App"},s.a.createElement("div",{className:"viewer"},s.a.createElement("div",{ref:function(t){return e.svg=t}}),s.a.createElement("div",{className:"messages"},s.a.createElement("pre",null,t))))}}]),t}(a.Component));Boolean("localhost"===window.location.hostname||"[::1]"===window.location.hostname||window.location.hostname.match(/^127(?:\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$/));r.a.render(s.a.createElement(d,null),document.getElementById("root")),"serviceWorker"in navigator&&navigator.serviceWorker.ready.then(function(e){e.unregister()})}},[[10,1,2]]]);
//# sourceMappingURL=main.c36ecb4a.chunk.js.map