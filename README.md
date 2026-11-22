# The Bloom Series: 3D Garden Invitations

**[▶ Live demo](https://kheleey.github.io/bloom-invitations/)** · Free to use under the [MIT License](LICENSE)

<p align="center"><img src="preview.gif" width="300" alt="Preview"></p>

### 🎬 Video tour

<a href="https://kheleey.github.io/bloom-invitations/tour.mp4"><img src="screenshot-1.jpg" width="260" alt="Watch the video tour"></a>

**[▶ Watch the full video tour](https://kheleey.github.io/bloom-invitations/tour.mp4)**

### Screenshots

<table><tr><td align="center"><img src="screenshot-1.jpg" width="200" alt="Cherry Blossom garden"><br><sub>Cherry Blossom garden</sub></td><td align="center"><img src="screenshot-2.jpg" width="200" alt="Rose: the invitation page"><br><sub>Rose: the invitation page</sub></td><td align="center"><img src="screenshot-3.jpg" width="200" alt="Lavender garden"><br><sub>Lavender garden</sub></td><td align="center"><img src="screenshot-4.jpg" width="200" alt="Sunflower: the reply page"><br><sub>Sunflower: the reply page</sub></td></tr></table>

Five event invitations, one per flower: Cherry Blossom, Tulip, Rose, Lavender and Sunflower. Each one is a living 3D card with its own garden growing on it. The garden has wind, butterflies and tiny guests strolling, chatting and picnicking.

Open a card and it unfolds into five pages you scroll through:

1. The invitation
2. The story behind the event
3. The programme
4. Practical details
5. The RSVP

Every invitation has its own frame shape and its own flower arrangements. You can pinch or double-tap to zoom in, add the event to Google Calendar, get directions, and send an RSVP.

## Make it yours

Everything you'll want to change is in the `window.BLOOM` block near the top of `index.html`:
- the series name, host, venue, address and RSVP email
- for each invitation: the title, date, times, dress code, welcome message, story, programme, notes and FAQ

## Built with

A single HTML file of plain JavaScript and [Three.js](https://threejs.org), which loads from a CDN, so it needs an internet connection. Fonts are from Google Fonts. The flowers are generated in code, with no 3D models.

## Use it for your own

1. Click **Fork** at the top of this page, or **Code → Download ZIP**.
2. Open `index.html` in any text editor and change the content block near the top.
3. Publish it with GitHub Pages (below), or open `index.html` in a browser.

Free to use, change and share, including commercially. Please keep the `LICENSE` file.

## Publish it as a website (GitHub Pages)

1. Upload this folder's files to a new **public** GitHub repository.
2. Go to **Settings → Pages**, choose **Deploy from a branch**, pick `main` and `/ (root)`, then click **Save**.
3. After a minute or two it's live at `https://<your-username>.github.io/<repo-name>/`.

You can also just open `index.html` in a browser.

## License

MIT. See [LICENSE](LICENSE).
