import React from "react";
import ReactDOM from "react-dom";
import { App } from "./app/App";
import { createRuntimeServices } from "./services/runtime";
import "./styles/tokens.css";
import "./styles/app.css";

ReactDOM.render(
  <React.StrictMode>
    <App services={createRuntimeServices()} />
  </React.StrictMode>,
  document.getElementById("root"),
);
