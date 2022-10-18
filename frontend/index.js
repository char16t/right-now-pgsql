function CallMe() {
    var request = new XMLHttpRequest();
    request.open('GET', 'http://localhost:3000/rpc/todo_list');
    request.send();
    request.onload = async function () {
        var data = JSON.parse(this.response);
        var root = document.getElementById("root");
        root.textContent = "";
        for (let i = 0; i < data.length; i++) {
            var todoList = document.createElement("div");
            todoList.setAttribute("id", "todo-list");
            var task = document.createElement("div");
            var taskTitle = document.createElement("div");
            taskTitle.textContent = data[i].title;
            task.appendChild(taskTitle);
            todoList.appendChild(task);
            root.appendChild(todoList);
        }
    }
}
CallMe();
