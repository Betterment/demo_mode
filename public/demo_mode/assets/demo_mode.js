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
      if (resp.status === 'failed') {
        document.querySelector("#LoadingMessage").classList.add("hidden");
        document.querySelector("#ErrorMessage").classList.remove("hidden");
      } else if (resp.status === 'processing') {
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
      var tables = document.querySelectorAll(`.${input.dataset.table}`);
      if (tables.length === 0) {
        alert("TableFilter cannot find its table");
        return;
      }
      Array.prototype.forEach.call(tables, function (table) {
        Array.prototype.forEach.call(table.tBodies, function (tbody) {
          Array.prototype.forEach.call(tbody.rows, filter);
        });
      });
      revealGroupsWithMatches();
    }

    function revealGroupsWithMatches() {
      var groups = document.querySelectorAll("details.persona-group");
      Array.prototype.forEach.call(groups, function (group) {
        var hasMatch = !!group.querySelector("tbody tr[data-matches]");
        group.open = inputValue !== "" && hasMatch;
      });
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
      var matches = text.indexOf(inputValue) !== -1;
      row.style.display = matches ? "table-row" : "none";
      if (matches) {
        row.setAttribute("data-matches", "");
      } else {
        row.removeAttribute("data-matches");
      }
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
