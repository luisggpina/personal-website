/*
     showEmail(linkid, cutid, n, d, x, nm, subj) displays a hyperlinked
     email address when viewed using a JavaScript-capable browser.

     Arguments:
         linkid: The id of the <a> element that should contain the
	         email address.
	 cutid: The id of an element to be removed, usually inside the
	        linkid element.
	 
	 n: The username of the mail address, with each character
	    xor'ed with x
	 d: Domainname of the address
	 subj: Subject line of the email (opt.)
     
     Example:
     
        <head>
	    ...
	    <script src="email.js" type="text/javascript"></script>
	</head>
	<body>
	...
	<a id="mailto" href="default.html" class="email">
	    <span id="cutme">
	    Turn on JavaScript to view the email address
	    </span>
	</a>
	<script type="text/javascript">
	    showEmail("mailto",  "cutme", "KDNX_", "cs.cornell.edu",
			42, "Andrew Myers");
	</script>

    Author: Andrew Myers, 2006
*/

function showEmail(linkid, cutid, n, d, x, nm, subj) {
    var link = document.getElementById(linkid);
    function xor_str(s, x) {
	var ret = "";
	for (i = 0; i < s.length; i++) // 'for i in s' doesn't work in IE
	    ret += String.fromCharCode(s.charCodeAt(i) ^ x);
	return ret;
    }

    n = xor_str(n, x);
   
    var text = document.createTextNode(n + "@" + d);

    var kid = document.getElementById(cutid);

    kid.onmouseover = function () {
	kid.parentNode.removeChild(kid);
	
	var url = "mailto:" + n + "@" + d + "%20(" + nm + ")";
	if (subj) {
	    url += "?Subject=[" + subj + "]%20"
	}
	link.setAttribute("href", url);
	link.setAttribute("class", "email");
	link.appendChild(text); // must do this after setting url b/c of IE!
    }
}
