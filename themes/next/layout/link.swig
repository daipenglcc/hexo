<script src="//at.alicdn.com/t/font_578712_g26jo2kbzd5qm2t9.js"></script>
<blockquote class="blockquote-center">{{ page.quotes }}</blockquote>
<h2>Blog friends</h2>
<ul class="ihoey-links">
  {% for e,i in site.data.links %}
    <li class="ihoey-links-item">
        <a href="{{ i.link }}" class="group-picture" title="{{ i.name }}" target="_blank">
            {% if i.avatar %}
              <img data-original="{{ i.avatar }}" loading="lazy" alt="{{ i.name }}" title="{{ i.name }}" height="72px" width="72px" />
              {% else %}
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-{{e+1}}" id="link"></use>
              </svg>
            {% endif %}
            <h3 class="ihoey-links-title" title="{{ i.name }}">{{ i.name }}</h3>
            <p class="ihoey-links-des" title="{{ i.description }}">{{ i.description }}</p>
        </a>
    </li>
  {% endfor %}
</ul>
<hr>
{% for i in page.declare %}
    <span>{{ i }}</span><br />
{% endfor %}
<hr>
<h3>友情链接添加须知</h3>
<ul style="padding: 0">
  {% for i in page.addNotes %}
      <li>{{ i }}</li>
  {% endfor %}
</ul>
<hr>
<h3>本站链接信息</h3>
<div style="background: #fbfbfb; border: 1px solid #eee; border-radius: 6px; padding: 15px 20px; font-size: 14px; line-height: 1.8;">
  <p style="margin: 4px 0;"><strong>名称：</strong>{{ config.title }}</p>
  <p style="margin: 4px 0;"><strong>地址：</strong><a href="{{ config.url }}" target="_blank" rel="noopener">{{ config.url }}</a></p>
  <p style="margin: 4px 0;"><strong>描述：</strong>{{ config.description }}</p>
  <p style="margin: 4px 0; word-break: break-all;"><strong>图片：</strong><a href="{{ config.avatar }}" rel="noopener nofollow" target="_blank">{{ config.avatar }}</a></p>
</div>
<hr>
