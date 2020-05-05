document.addEventListener("DOMContentLoaded", function () {
	  document.getElementById('button').addEventListener('click',displayblock);
    function displayblock () {
      for (var i = 0, div = document.getElementsByClassName('masterroute'); i < div.length; i++) {
        div[i].style.display = 'block';
      }
    }
});
