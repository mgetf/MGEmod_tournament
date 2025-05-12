extern crate challonge as challonge_api;

use std::collections::{HashMap, HashSet};

use actix::{Actor, AsyncContext, StreamHandler};
use actix_files::{Files, NamedFile};
use actix_web::{
    get, guard::All, post, web, App, Error, HttpRequest, HttpResponse, HttpServer, Responder,
};
use actix_web_actors::ws;
use serde::{Deserialize, Serialize};
mod server;

#[derive(Debug, Deserialize, Serialize)]

#[derive(Clone)]
struct Player {
    steam_id: String,
    name: String,
}

// Browser-specific messages
#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type", content = "payload")]
enum BrowserCommand {
    Init {},
    TeleportPlayer { steam_id: String },
}

// Server-specific messages
#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type", content = "payload")]
enum ServerCommand {
    ServerHello {},
    PlayerJoined { steam_id: String, name: String },
}

// Responses to browsers
#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type", content = "payload")]
enum BrowserResponse {
    Error { message: String },
    IdiomorphUpdate { target_id: String, html_content: String },
}

// Responses to servers
#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type", content = "payload")]
enum ServerResponse {
    ServerAck {},
    TeleportPlayer { steam_id: String },
    Error { message: String },
}

struct AppState {
    ladder: actix::Addr<server::Ladder>,
}

use crate::server::Ladder;
use actix::prelude::*;

// Message to forward browser commands to the ladder
#[derive(Message)]
#[rtype(result = "()")]
struct BrowserMsg {
    command: BrowserCommand,
    from: Addr<admin_ws::AdminWs>,
}

// Message to forward server commands to the ladder
#[derive(Message)]
#[rtype(result = "()")]
struct ServerMsg {
    command: ServerCommand,
    from: Addr<server_ws::GameServerWs>,
}

// Disconnect notification messages
#[derive(Message)]
#[rtype(result = "()")]
struct AdminDisconnected {
    addr: Addr<admin_ws::AdminWs>,
}

#[derive(Message)]
#[rtype(result = "()")]
struct ServerDisconnected {
    addr: Addr<server_ws::GameServerWs>,
}

// Admin WebSocket handler
mod admin_ws {
    use super::*;

    pub struct AdminWs {
        pub ladder: Addr<Ladder>,
    }

    impl Actor for AdminWs {
        type Context = ws::WebsocketContext<Self>;

        fn stopped(&mut self, _ctx: &mut Self::Context) {
            // Notify the ladder that this admin has disconnected
            self.ladder.do_send(AdminDisconnected {
                addr: _ctx.address(),
            });
            println!("Admin websocket connection closed");
        }
    }

    impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for AdminWs {
        fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
            match msg {
                Ok(ws::Message::Ping(msg)) => ctx.pong(&msg),
                Ok(ws::Message::Pong(_)) => println!("Pong received"),
                Ok(ws::Message::Text(text)) => {
                    println!("Admin text received: {}", text);
                    let parsed: Result<BrowserCommand, serde_json::Error> = serde_json::from_str(&text);
                    match parsed {
                        Ok(cmd) => {
                            self.ladder.do_send(BrowserMsg {
                                command: cmd,
                                from: ctx.address(),
                            });
                        }
                        Err(e) => {
                            let error_resp = BrowserResponse::Error {
                                message: e.to_string(),
                            };
                            let st = serde_json::to_string(&error_resp).unwrap();
                            ctx.text(st);
                        }
                    }
                }
                Ok(ws::Message::Binary(bin)) => ctx.binary(bin),
                Ok(ws::Message::Close(reason)) => {
                    println!("Admin websocket closing: {:?}", reason);
                    ctx.close(reason);
                },
                _ => (),
            }
        }
    }

    // Add response handler for AdminWs
    #[derive(Message)]
    #[rtype(result = "()")]
    pub struct AdminResponse {
        pub response: BrowserResponse,
    }

    impl Handler<AdminResponse> for AdminWs {
        type Result = ();

        fn handle(&mut self, msg: AdminResponse, ctx: &mut Self::Context) {
            let st = serde_json::to_string(&msg.response).unwrap();
            ctx.text(st);
        }
    }
}

// Game Server WebSocket handler
mod server_ws {
    use super::*;

    pub struct GameServerWs {
        pub ladder: Addr<Ladder>,
    }

    impl Actor for GameServerWs {
        type Context = ws::WebsocketContext<Self>;

        fn stopped(&mut self, _ctx: &mut Self::Context) {
            // Notify the ladder that this server has disconnected
            self.ladder.do_send(ServerDisconnected {
                addr: _ctx.address(),
            });
            println!("Server websocket connection closed");
        }
    }

    impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for GameServerWs {
        fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
            match msg {
                Ok(ws::Message::Ping(msg)) => ctx.pong(&msg),
                Ok(ws::Message::Pong(_)) => println!("Pong received"),
                Ok(ws::Message::Text(text)) => {
                    println!("Server text received: {}", text);
                    let parsed: Result<ServerCommand, serde_json::Error> = serde_json::from_str(&text);
                    match parsed {
                        Ok(cmd) => {
                            self.ladder.do_send(ServerMsg {
                                command: cmd,
                                from: ctx.address(),
                            });
                        }
                        Err(e) => {
                            let error_resp = ServerResponse::Error {
                                message: e.to_string(),
                            };
                            let st = serde_json::to_string(&error_resp).unwrap();
                            ctx.text(st);
                        }
                    }
                }
                Ok(ws::Message::Binary(bin)) => ctx.binary(bin),
                Ok(ws::Message::Close(reason)) => {
                    println!("Server websocket closing: {:?}", reason);
                    ctx.close(reason);
                },
                _ => (),
            }
        }
    }

    // Add response handler for GameServerWs
    #[derive(Message)]
    #[rtype(result = "()")]
    pub struct ServerResponseMsg {
        pub response: ServerResponse,
    }

    impl Handler<ServerResponseMsg> for GameServerWs {
        type Result = ();

        fn handle(&mut self, msg: ServerResponseMsg, ctx: &mut Self::Context) {
            let st = serde_json::to_string(&msg.response).unwrap();
            ctx.text(st);
        }
    }
}

async fn admin_ws_route(
    req: HttpRequest,
    data: web::Data<AppState>,
    stream: web::Payload,
) -> Result<HttpResponse, Error> {
    let t: &actix::Addr<server::Ladder> = &data.ladder;
    let resp = ws::start(
        admin_ws::AdminWs { ladder: t.clone() },
        &req,
        stream,
    );
    println!("new admin connection");
    resp
}

async fn server_ws_route(
    req: HttpRequest,
    data: web::Data<AppState>,
    stream: web::Payload,
) -> Result<HttpResponse, Error> {
    let t: &actix::Addr<server::Ladder> = &data.ladder;
    let resp = ws::start(
        server_ws::GameServerWs { ladder: t.clone() },
        &req,
        stream,
    );
    println!("new server connection");
    resp
}

async fn admin() -> impl Responder {
    NamedFile::open_async("./static/admin.html").await.unwrap()
}

async fn index() -> impl Responder {
    NamedFile::open_async("./static/index.html").await.unwrap()
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let ladder = Ladder::new().start();

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(AppState {
                ladder: ladder.clone(),
            }))
            .route("/admin_ws", web::get().to(admin_ws_route))
            .route("/server_ws", web::get().to(server_ws_route))
            .route("/admin", web::get().to(admin))
            .route("/", web::get().to(index))
    })
    .bind(("0.0.0.0", 8083))?
    .run()
    .await
}
