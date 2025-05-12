use actix::prelude::*;
use crate::{admin_ws, server_ws, BrowserCommand, ServerCommand, BrowserResponse, ServerResponse};

const NUM_ARENAS: usize = 16;

pub struct Ladder {
    admin: Option<actix::Addr<crate::admin_ws::AdminWs>>,
    servers: Vec<actix::Addr<crate::server_ws::GameServerWs>>,
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

// Helper function to update admin UI
pub fn update_admin(admin_client_addr: &actix::Addr<crate::admin_ws::AdminWs>, new_html_content: Markup) {
    let response = BrowserResponse::IdiomorphUpdate {
        target_id: "app".to_string(),
        html_content: new_html_content.into_string(),
    };
    admin_client_addr.do_send(admin_ws::AdminResponse {
        response,
    });
}

use maud::{html, Markup};

// Handle browser commands
impl Handler<crate::BrowserMsg> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: crate::BrowserMsg, _ctx: &mut Self::Context) {
        match msg.command {
            BrowserCommand::Init {} => {
                self.admin = Some(msg.from.clone());
                update_admin(&msg.from, html! {
                    div class="flex flex-col items-center justify-center h-screen" #app {
                        input class="border-2 border-gray-300 rounded-md p-2" type="text" #steamid placeholder="SteamID" {}
                        button class="bg-blue-500 text-white p-2 rounded-md cursor-pointer" onclick={
                            "sm({type: 'TeleportPlayer', payload: {steamid: $('#steamid').val()}});"
                            "$('#steamid').val('');"
                        } { "teleport yer" }
                     }
                });
            }
            BrowserCommand::TeleportPlayer { steamid } => {
                for server in self.servers.iter() {
                    server.do_send(server_ws::ServerResponseMsg {
                        response: ServerResponse::TeleportPlayer { steamid: steamid.clone() },
                    });
                }
            }
        }
    }
}

// Handle game server commands
impl Handler<crate::ServerMsg> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: crate::ServerMsg, _ctx: &mut Self::Context) {
        match msg.command {
            ServerCommand::ServerHello {} => {
                // Add the server to our list
                self.servers.push(msg.from.clone());
                
                // Send acknowledgement back to the server
                msg.from.do_send(server_ws::ServerResponseMsg {
                    response: ServerResponse::ServerAck {},
                });
            }
        }
    }
}
