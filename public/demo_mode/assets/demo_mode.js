(function (document, performance, location) {
  function* getJSON(url) {
    while (true) {
      yield fetch(url).then((resp) => resp.json());
    }
  }

  function pollURL(url, minInterval, success, func) {
    const then = performance.now();
    if (!minInterval) {
      minInterval = 1000;
    }
    if (!func) {
      func = getJSON(url);
    }

    func.next().value.then((resp) => {
      if (resp.error) {
        document.querySelector("#LoadingMessage").classList.add("hidden");
        document.querySelector("#ErrorMessage").classList.remove("hidden");
      } else if (resp.processing) {
        setTimeout(
          () => pollURL(url, minInterval, success, func),
          Math.max(0, minInterval - (performance.now() - then))
        );
      } else {
        success();
      }
    });
  }

  document.addEventListener("DOMContentLoaded", (event) => {
    [...document.querySelectorAll("[data-polling-refresh-url]")].forEach(
      (elem) => {
        pollURL(
          elem.getAttribute("data-polling-refresh-url"),
          elem.getAttribute("data-polling-refresh-interval") * 1000,
          () => location.reload()
        );
      }
    );
  });
})(document, performance, location);

(function () {
  var TableFilter = (function () {
    var input;
    var inputValue;

    function onInputEvent(e) {
      input = e.target;
      inputValue = input.value.toLowerCase().replace(/[^0-9a-zA-Z ]/g, "");
      updateTable();
      updateHistory();
    }

    function updateTable() {
      var table = document.querySelector(`.${input.dataset.table}`);
      if (table) {
        Array.prototype.forEach.call(table.tBodies, function (tbody) {
          Array.prototype.forEach.call(tbody.rows, filter);
        });
      } else {
        alert("TableFilter cannot find its table");
      }
    }

    function updateHistory() {
      var searchParams = new URLSearchParams(window.location.search);
      searchParams.set("search", inputValue);
      var newRelativePathQuery =
        window.location.pathname + "?" + searchParams.toString();
      history.pushState(null, "", newRelativePathQuery);
    }

    function filter(row) {
      var text = row.textContent.toLowerCase().replace(/[^0-9a-zA-Z ]/g, "");
      row.style.display =
        text.indexOf(inputValue) === -1 ? "none" : "table-row";
    }

    function debounce(func, threshold) {
      var timeout;

      return function debounced() {
        var obj = this;
        var args = arguments;

        function delayed() {
          func.apply(obj, args);
          timeout = null;
        }

        if (timeout) {
          clearTimeout(timeout);
        }
        timeout = setTimeout(delayed, threshold);
      };
    }

    return {
      init: function () {
        var input = document.querySelector("input[data-behavior=table-filter]");
        if (!input) return;

        input.oninput = debounce(onInputEvent, 250);
        var urlParams = new URLSearchParams(window.location.search);
        var search = urlParams.get("search");
        if (search) {
          input.value = search;
          input.dispatchEvent(new InputEvent("input", { data: search }));
        }

        window.addEventListener("popstate", (event) => {
          var urlParams = new URLSearchParams(window.location.search);
          var search = urlParams.get("search");
          if (search) {
            input.value = search;
            inputValue = search;
            updateTable();
          }
        });
      },
    };
  })();

  document.addEventListener("DOMContentLoaded", (event) => {
    TableFilter.init();
  });
})();
