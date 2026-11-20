const $ = id => document.getElementById(id);
chrome.runtime.sendMessage({ type: 'view' }).then(r => {
  if (!r?.target) { $('status').textContent = 'Yêu cầu đã hết hạn. Đóng cửa sổ này.'; return; }
  $('origin').textContent = r.origin;
  $('target').textContent = r.target;
  $('approve').disabled = false;
});
for (const [id, type] of [['approve', 'approve'], ['deny', 'deny']]) {
  $(id).addEventListener('click', () => {
    $('approve').disabled = true; $('deny').disabled = true;
    chrome.runtime.sendMessage({ type }).then(() => window.close());
  });
}
