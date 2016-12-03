Element.prototype.matches = Element.prototype.matches || Element.prototype.matchesSelector || Element.prototype.mozMatchesSelector || Element.prototype.msMatchesSelector || Element.prototype.oMatchesSelector || Element.prototype.webkitMatchesSelector;

var u = {
	addClass: function(clazz) {
		return function(e) {
			e.target.classList.add(clazz);
		}
	},
	loader: function() {
		return function(e) {
			var icon = e.target.matches("i.icon") ? e.target : e.target.querySelector("i.icon");

			icon.className = "notched circle loading icon";
		}
	},
	authConfig: function(xhr) {
		xhr.setRequestHeader("Authorization", localStorage.token)
	}
}

var MainComponent = {
	"controller": function() {
		document.title = "OmniBot";
	},
	"view": function() {
		return m("div.main page", [
			m(".header box", [
				m("h1", "OmniBot"),
				m("p", "A fun and useful Discord bot!"),
				m("a.ui green button", { href: "/discord/join" }, "Get OmniBot!"),
				m("a.ui violet button", { href: (localStorage.token ? "/#/dash" : "/discord/login"), onclick: u.addClass("loading") }, "Dashboard")
			])
		])
		//return m("a", { href: "/guild/207547192125161472/home", config: m.route }, "Freelo Test")
	}
}

var SMParts = {}

SMParts.home = {
	"view": function(ctrl, c) {
		return m("div", [
			m("h2.ui header", "Server: ", m("span", c.guild().name)),
			m(".ui segment", [
				m("h3.ui header", "Server Info"),
				m("p", m("b", "ID: "), c.guild().id),
				m("p", m("b", "Members: "), c.guild().member_count)
			])
		])
	}
}

SMParts.jukebox = {
	"controller": function(c) {
		return {
			queue: m.request({ method: "GET", url: "/api/" + c.guild().id + "/jukebox/queue" }),
			np: m.request({ method: "GET", url: "/api/" + c.guild().id + "/jukebox/np" })
		}
	},
	"view": function(ctrl, c) {
		return m("div", [
			m("h2.ui header", "Jukebox"),
			m("div.ui icon message", [
				m("i.play icon"),
				m(".content", ctrl.np().title ? [
					m(".header", "Now playing in " + ctrl.np().channel.name + ":"),
					m("p", ctrl.np().title)
				] : [
					m(".header", "Nothing's currently playing. Add a song!")
				])
			]),
			m(".ui segment", [
				m("h3.ui header", "Queue"),
				m("table.ui celled table", [
					m("thead", [
						m("tr", [
							m("th", "Title"),
							m("th", "Source")
						])
					]),
					m("tbody", [
						ctrl.queue().queue.map(function(song) {
							return m("tr", [
								m("td", song.title),
								m("td", song.type)
							])
						})
					])
				])
			])
		])
	}
}

SMParts.config = {
	"view": function(ctrl, c) {
		return m("div", [
			m("h2.ui header", m.trust("Settings coming soon&#8482;"))
		])
	}
}

var ServerManagementComponent = {
	"controller": function() {
		var id = m.route.param("guild"),
			page = m.route.param("page");

		var ctrl = {
			guild: m.request({ method: "GET", url: "/api/" + id + "/info" }),
			user: m.request({ method: "GET", url: "/pr/user", config: u.authConfig }),
			route: "/guild/" + id,
			menuState: "visible",
			component: SMParts[page]
		}

		if (window.screen.width < 500) {
			ctrl.mobile = true;
			ctrl.menuState = "fixed";
		}

		return ctrl;
	},
	"view": function(ctrl) {
		document.title = "OmniBot | " + ctrl.guild().name;

		return m("div", [
			m(".ui left vertical inverted menu sidebar", { className: ctrl.menuState, id: "main-menu" }, [
				m("div.header item", "OmniBot Web Panel"),
				m("a.item", { href: ctrl.route + "/home", config: m.route }, m("i.home icon"), "Home"),
				m("a.item", { href: ctrl.route + "/jukebox", config: m.route, onclick: u.loader() }, m("i.music icon"), "Jukebox"),
				m("a.item", { href: ctrl.route + "/config", config: m.route }, m("i.settings icon"), "Settings"),
				m("a.item", { href: "/dash", config: m.route, onclick: u.loader() }, m("i.server icon"), "Switch Servers"),
				m("p.disabled item", m("i.sign in icon"), "Logged in as " + ctrl.user().username)
			]),
			m(".pusher", [
				m("button.ui basic compact icon button", { style: ctrl.mobile ? "position:absolute;top:5px;right:5px;" : "display:none;", onclick: function() {
					document.getElementById("main-menu").classList.add("visible")
				} }, [
					m("i.content icon")
				]),
				m.component(ctrl.component, ctrl)
			])
		])
	}
}

var ServerPicker = {
	"controller": function() {
		var token = m.route.param("token");

		if (token) {
			localStorage.token = token;
		}

		if (!localStorage.token) {
			window.location.href = window.location.origin + "/discord/login";
			return;
		}

		var ctrl = {
			guilds: m.request({ method: "GET", url: "/pr/guilds", initialValue: [], config: u.authConfig })
		}

		document.title = "OmniBot | Your Guilds";

		return ctrl
	},
	"view": function(ctrl) {
		return m("div.ui text container", [
			m("h1.ui centered header", "Your Guilds"),
			m(".ui relaxed divided list", [
				ctrl.guilds().map(function(guild) {
					return m(".item", [
						m("img.ui avatar image", { src: "https://cdn.discordapp.com/icons/" + guild.id + "/" + guild.icon + ".jpg" }),
						m(".content", [
							m("a.header", { href: "/guild/" + guild.id + "/home", config: m.route }, guild.name)
						])
					])
				})
			])
		])
	}
}

window.addEventListener("load", function() {
	m.route.mode = "hash";
	m.route(document.body, "/", {
		"/": MainComponent,
		"/dash": ServerPicker,
		"/guild/:guild/:page": ServerManagementComponent
	})
})
