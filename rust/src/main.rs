extern crate challonge as challonge_api;

use std::collections::{HashMap, HashSet};

use actix::{Actor, AsyncContext, StreamHandler};
use actix_files::{Files, NamedFile};
use actix_web::{
    get, guard::All, post, web, App, Error, HttpRequest, HttpResponse, HttpServer, Responder,
};
use actix_web_actors::ws;
use serde::{Deserialize, Serialize};
mod challonge;
mod server;

#[derive(Debug, Deserialize, Serialize)]
struct Player {
    steamId: String,
    name: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type", content = "payload")]
enum MessagePayload {
    // receiving
    ServerHello {
        apiKey: String,
        serverNum: String,
        serverHost: String,
        serverPort: String,
        stvPort: String,
    },
    // sending
    MatchDetails {
        arenaId: i32,
        p1Id: String,
        p2Id: String,
    },
    MatchBegan {
        p1Id: String,
        p2Id: String,
    },
    TournamentStart {},
    TournamentStop {},
    MatchResults {
        winner: String,
        loser: String,
        finished: bool,
        arena: i32,
    },
    MatchCancel {
        delinquents: Vec<String>,
        arrived: String,
        arena: i32,
    },
    UsersInServer {
        players: Vec<Player>,
    },
    Error {
        message: String,
    },
    SetMatchScore {
        arenaId: i32,
        p1Score: i32,
        p2Score: i32,
    },
}

struct AppState {
    app_name: String,
    tournment: actix::Addr<server::Tournament>,
}

use crate::server::Tournament;
use actix::prelude::*;

// https://github.com/actix/examples/blob/master/websockets/chat/src/server.rs
struct ServerWs {
    addr: Addr<Tournament>,
}
impl Actor for ServerWs {
    type Context = ws::WebsocketContext<Self>;
}

#[derive(Message)]
#[rtype(result = "()")]
struct ForwardMessage {
    message: MessagePayload,
    from: Addr<ServerWs>,
}

impl Handler<ForwardMessage> for ServerWs {
    type Result = ();

    fn handle(&mut self, msg: ForwardMessage, ctx: &mut Self::Context) {
        println!("Forwarding message: {:?}", msg.message);
        let st = serde_json::to_string(&msg.message).unwrap();
        ctx.text(st);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for ServerWs {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => ctx.pong(&msg),
            Ok(ws::Message::Pong(_)) => println!("Pong received"),
            Ok(ws::Message::Text(text)) => {
                println!("Text received: {}", text);
                let parsed: Result<MessagePayload, serde_json::Error> = serde_json::from_str(&text);
                match parsed {
                    Ok(p) => {
                        self.addr.do_send(ForwardMessage {
                            message: p,
                            from: ctx.address(),
                        });
                    }
                    Err(e) => {
                        self.addr.do_send(ForwardMessage {
                            message: MessagePayload::Error {
                                message: e.to_string(),
                            },
                            from: ctx.address(),
                        });
                    }
                }
            }
            Ok(ws::Message::Binary(bin)) => ctx.binary(bin),
            _ => (),
        }
    }
}

async fn server_route(
    req: HttpRequest,
    data: web::Data<AppState>,
    stream: web::Payload,
) -> Result<HttpResponse, Error> {
    let t: &actix::Addr<server::Tournament> = &data.tournment;

    let resp = ws::start(ServerWs { addr: t.clone() }, &req, stream);
    println!("server!!! {:?}", resp);
    resp
}

async fn admin() -> impl Responder {
    NamedFile::open_async("./static/admin.html").await.unwrap()
}

async fn index() -> impl Responder {
    NamedFile::open_async("./static/index.html").await.unwrap()
}

use actix_web::rt::task;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // read api_key.txt
    let api_key = std::fs::read_to_string("api_key.txt").unwrap();
    let c = challonge::Challonge::new("tommylt3", &api_key.trim());
    let tournament = Tournament::new(c).start();

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(AppState {
                app_name: String::from("Actix-web"),
                tournment: tournament.clone(),
            }))
            .route("/tf2serverep", web::get().to(server_route))
            .route("/admin", web::get().to(admin))
            .route("/", web::get().to(index))
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}

// fn main() {
//     let c = challonge_api::Challonge::new("tommylt3", crate::challonge::API_KEY);
//     let tid = challonge_api::TournamentId::Url(
//         crate::challonge::SUBDOMAIN.to_string(),
//         "mge2".to_string(),
//     );

//     crate::challonge::get_matches(&tid);
// }
