use crate::ForwardMessage;
use actix::prelude::*;

const NUM_ARENAS: usize = 16;

pub struct Ladder {
    admin: Option<actix::Addr<crate::ServerWs>>,
    servers: Vec<actix::Addr<crate::ServerWs>>,
    players: Vec<crate::Player>,
}

impl Ladder {
    pub fn new() -> Self {
        Ladder {
            admin: None,
            servers: vec![],
            players: vec![],
        }
    }
}

impl Actor for Ladder {
    type Context = Context<Self>;
}

use crate::MessagePayload;
use reqwest;

pub fn update(admin_client_addr: actix::Addr<crate::ServerWs>, new_html_content: Markup) {
    let reply_payload = MessagePayload::IdiomorphUpdate {
        target_id: "app".to_string(),
        html_content: new_html_content.into_string(),
    };
    admin_client_addr.do_send(crate::ForwardMessage {
        message: reply_payload,
        from: admin_client_addr.clone(),
    });
}
pub fn sm(o: MessagePayload) -> String {
    let json = serde_json::to_string(&o).unwrap();
    format!("sm({})", json)
}

use maud::{html, Markup};

impl Handler<crate::ForwardMessage> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: ForwardMessage, ctx: &mut Self::Context) {
        match msg.message {
            MessagePayload::Init {} => {
                self.admin = Some(msg.from.clone());
                update(msg.from, html! {
                    div class="flex flex-col items-center justify-center h-screen" #app {
                        input class="border-2 border-gray-300 rounded-md p-2" type="text" id="steamid" placeholder="SteamID" {}
                        button class="bg-blue-500 text-white p-2 rounded-md cursor-pointer" onclick={
                            "sm({type: 'TeleportPlayer', payload: {steamid: $('#steamid').val()}});"
                            "$('#steamid').val('');"
                        } { "teleport yer" }
                     }
                });
            }
            MessagePayload::ServerHello {} => {
                self.servers.push(msg.from);
            }
            MessagePayload::ServerAck {} => {
                println!("ServerAck");
            }
            MessagePayload::TeleportPlayer { steamid } => {
                for server in self.servers.iter() { 
                    server.do_send(crate::ForwardMessage {
                        message: crate::MessagePayload::TeleportPlayer { steamid: steamid.clone() },
                        from: msg.from.clone(),
                    });
                }
            }
            MessagePayload::Error { message } => {
                panic!("Error: {}", message);
            }
            MessagePayload::IdiomorphUpdate {
                target_id,
                html_content,
            } => {
                panic!("IdiomorphUpdate: {} {}", target_id, html_content);
            }
        }
    }
}
