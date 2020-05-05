'use strict';
document.addEventListener('DOMContentLoaded', function () {

  document.querySelector('#on').addEventListener('click',showhidestats);
  document.querySelector('#off').addEventListener('click',showhidestats);

  function showhidestats(event){ 
    event.target.parentNode.classList.toggle('hide');
  }
  
});
