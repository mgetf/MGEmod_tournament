use actix::prelude::*;
use crate::{admin_ws, server_ws, BrowserCommand, ServerCommand, BrowserResponse, ServerResponse};
use crate::{AdminDisconnected, ServerDisconnected};
use maud::{html, Markup};

pub struct Ladder {
    admins: Vec<actix::Addr<crate::admin_ws::AdminWs>>,
    servers: Vec<actix::Addr<crate::server_ws::GameServerWs>>,
    players: Vec<crate::Player>,
}

impl Ladder {
    pub fn new() -> Self {
        Ladder {
            admins: vec![],
            servers: vec![],
            players: vec![],
        }
    }

    pub fn render_admin_ui(&self) -> Markup {
        html! {
            div class="flex flex-col items-center justify-center h-screen" #app {
                h1 class="text-2xl font-bold" { "Servers" }
                @for server in self.servers.iter() {
                    p { (format!("{:?}", server)) }
                }
                h1 class="text-2xl font-bold" { "Admins" }
                @for admin in self.admins.iter() {
                    p { (format!("{:?}", admin)) }
                }
                h1 class="text-2xl font-bold" { "Ladder" }
                input class="border-2 border-gray-300 rounded-md p-2" type="text" #steamid placeholder="SteamID" {}
                button class="bg-blue-500 text-white p-2 rounded-md cursor-pointer" onclick={
                    "sm({type: 'TeleportPlayer', payload: {steam_id: $('#steamid').val()}});"
                    "$('#steamid').val('');"
                } { "teleport here" }
            }
        }
    }

    pub fn rerender_all_admins(&self) {
        for admin in self.admins.iter() {
            update_admin(admin, self.render_admin_ui());
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

// Handle browser commands
impl Handler<crate::BrowserMsg> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: crate::BrowserMsg, _ctx: &mut Self::Context) {
        match msg.command {
            BrowserCommand::Init {} => {
                self.admins.push(msg.from.clone());
                update_admin(&msg.from, self.render_admin_ui());
            }
            BrowserCommand::TeleportPlayer { steam_id } => {
                for server in self.servers.iter() {
                    server.do_send(server_ws::ServerResponseMsg {
                        response: ServerResponse::TeleportPlayer { steam_id: steam_id.clone() },
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
            ServerCommand::PlayerJoined { steam_id, name } => {
                self.players.push(crate::Player { steam_id, name });
                self.rerender_all_admins();
            }
            ServerCommand::ServerHello {} => {
                // Add the server to our list
                self.servers.push(msg.from.clone());
                
                // Send acknowledgement back to the server
                msg.from.do_send(server_ws::ServerResponseMsg {
                    response: ServerResponse::ServerAck {},
                });
                self.rerender_all_admins();
            }
        }
    }
}

// Handle admin disconnections
impl Handler<AdminDisconnected> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: AdminDisconnected, _ctx: &mut Self::Context) {
        println!("Removing disconnected admin");
        // Remove the disconnected admin from the list
        self.admins.retain(|admin| admin != &msg.addr);
        self.rerender_all_admins();
    }
}

// Handle server disconnections
impl Handler<ServerDisconnected> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: ServerDisconnected, _ctx: &mut Self::Context) {
        println!("Removing disconnected server");
        // Remove the disconnected server from the list
        self.servers.retain(|server| server != &msg.addr);
        self.rerender_all_admins();
    }
}
